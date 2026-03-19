#include "jlview.h"

/* ---------------------------------------------------------------------------
 * Julia C API function pointers — resolved in C_jlview_init_runtime via dlsym.
 * JuliaCall loads libjulia with RTLD_GLOBAL, making these symbols available.
 * --------------------------------------------------------------------------- */
jl_value_t* (*jl_eval_string_ptr)(const char*) = NULL;
jl_value_t* (*jl_call1_ptr)(jl_value_t*, jl_value_t*) = NULL;
jl_value_t* (*jl_box_uint64_ptr)(uint64_t) = NULL;
int64_t     (*jl_unbox_int64_ptr)(jl_value_t*) = NULL;
uint64_t    (*jl_unbox_uint64_ptr)(jl_value_t*) = NULL;
void*       (*jl_unbox_voidpointer_ptr)(jl_value_t*) = NULL;
jl_value_t* (*jl_get_field_ptr)(jl_value_t*, const char*) = NULL;
jl_value_t* (*jl_exception_occurred_ptr)(void) = NULL;
void*       (*jl_array_ptr_ptr)(jl_value_t*) = NULL;

/* Cached JlviewSupport function pointers */
jl_value_t* jl_pin_func = NULL;
jl_value_t* jl_unpin_func = NULL;
jl_value_t* jl_sum_func = NULL;
jl_value_t* jl_minimum_func = NULL;
jl_value_t* jl_maximum_func = NULL;
double (*jl_unbox_float64_ptr)(jl_value_t*) = NULL;

/* Runtime state */
int jlview_julia_is_alive = 0;
pid_t jlview_init_pid = 0;

/* ---------------------------------------------------------------------------
 * C_jlview_init_runtime — resolve all Julia C API symbols at runtime.
 * Called from .onLoad AFTER JuliaCall::julia_setup() has loaded libjulia.
 * --------------------------------------------------------------------------- */
SEXP C_jlview_init_runtime(void) {
    jlview_julia_is_alive = 1;
    jlview_init_pid = getpid();

    /* Resolve Julia C API symbols (available via RTLD_GLOBAL) */
    LOAD_JL_SYMBOL(jl_eval_string_ptr,        "jl_eval_string");
    LOAD_JL_SYMBOL(jl_call1_ptr,              "jl_call1");
    LOAD_JL_SYMBOL(jl_box_uint64_ptr,         "jl_box_uint64");
    LOAD_JL_SYMBOL(jl_unbox_int64_ptr,        "jl_unbox_int64");
    LOAD_JL_SYMBOL(jl_unbox_uint64_ptr,       "jl_unbox_uint64");
    LOAD_JL_SYMBOL(jl_unbox_voidpointer_ptr,  "jl_unbox_voidpointer");
    LOAD_JL_SYMBOL(jl_get_field_ptr,          "jl_get_field");
    LOAD_JL_SYMBOL(jl_exception_occurred_ptr, "jl_exception_occurred");
    LOAD_JL_SYMBOL(jl_array_ptr_ptr,           "jl_array_ptr");

    /* Resolve JlviewSupport functions */
    jl_pin_func = jl_eval_string_ptr("JlviewSupport.pin");
    jl_unpin_func = jl_eval_string_ptr("JlviewSupport.unpin");
    if (jl_pin_func == NULL || jl_unpin_func == NULL) {
        Rf_error("jlview: failed to resolve JlviewSupport functions. "
                 "Is JlviewSupport loaded?");
    }

    /* Resolve summary statistic functions for ALTREP Sum/Min/Max */
    jl_sum_func = jl_eval_string_ptr("JlviewSupport.pinned_sum");
    jl_minimum_func = jl_eval_string_ptr("JlviewSupport.pinned_minimum");
    jl_maximum_func = jl_eval_string_ptr("JlviewSupport.pinned_maximum");
    LOAD_JL_SYMBOL(jl_unbox_float64_ptr, "jl_unbox_float64");

    return R_NilValue;
}

/* ---------------------------------------------------------------------------
 * C_jlview_shutdown — mark Julia as dead before final GC sweep.
 * Called from .onUnload.
 * --------------------------------------------------------------------------- */
SEXP C_jlview_shutdown(void) {
    jlview_julia_is_alive = 0;
    jl_pin_func = NULL;
    jl_unpin_func = NULL;
    jl_sum_func = NULL;
    jl_minimum_func = NULL;
    jl_maximum_func = NULL;
    return R_NilValue;
}

/* ---------------------------------------------------------------------------
 * jlview_pointer_finalizer — unpin Julia array when R external pointer is GC'd.
 *
 * Three guards protect against unsafe calls:
 *   1. pin_id_sexp == R_NilValue → already released (double-free protection)
 *   2. jlview_julia_is_alive     → Julia runtime still running
 *   3. getpid() == jlview_init_pid → not in a forked child (mclapply safety)
 * --------------------------------------------------------------------------- */
void jlview_pointer_finalizer(SEXP extptr) {
    /* Guard 1: already released? */
    SEXP pin_id_sexp = R_ExternalPtrTag(extptr);
    if (pin_id_sexp == R_NilValue) return;

    /* Guard 2: Julia still alive?  Guard 3: same process (not a fork)? */
    if (jlview_julia_is_alive && getpid() == jlview_init_pid
            && jl_unpin_func != NULL) {
        uint64_t pin_id;
        memcpy(&pin_id, RAW(pin_id_sexp), sizeof(uint64_t));

        /* Call Julia directly via C API — safe during R GC.
         * jl_box_uint64 allocates on Julia's heap; this is safe because
         * R and Julia have independent allocators. */
        jl_value_t* jl_id = jl_box_uint64_ptr(pin_id);
        jl_value_t* jl_result = jl_call1_ptr(jl_unpin_func, jl_id);
        if (jl_exception_occurred_ptr() || jl_result == NULL) {
            /* Leak Julia memory rather than crash in finalizer */
            R_ClearExternalPtr(extptr);
            R_SetExternalPtrTag(extptr, R_NilValue);
            return;
        }
        size_t freed_bytes = (size_t)jl_unbox_int64_ptr(jl_result);

        jlview_track_free(freed_bytes);
    }
    /* If Julia is dead or we're in a fork, skip unpin — memory will be
     * reclaimed by process exit (fork) or is already freed (shutdown). */

    /* Always clear the pointer to prevent double-free */
    R_ClearExternalPtr(extptr);
    R_SetExternalPtrTag(extptr, R_NilValue);
}

/* ---------------------------------------------------------------------------
 * C_jlview_release — explicit release from R (called by user code).
 * Extracts the external pointer from an ALTREP object and finalizes it.
 * --------------------------------------------------------------------------- */
SEXP C_jlview_release(SEXP x) {
    SEXP extptr = R_altrep_data1(x);
    SEXP pin_id_sexp = R_ExternalPtrTag(extptr);
    if (pin_id_sexp == R_NilValue) {
        Rf_warning("jlview_release: object was already released");
        return R_NilValue;
    }
    jlview_pointer_finalizer(extptr);
    return R_NilValue;
}

/* ---------------------------------------------------------------------------
 * select_class — map element type code to the corresponding ALTREP class.
 * --------------------------------------------------------------------------- */
static R_altrep_class_t select_class(int eltcode) {
    switch (eltcode) {
    case JLVIEW_FLOAT64:
        return jlview_real_class;
    case JLVIEW_INT32:
        return jlview_integer_class;
    default:
        Rf_error("jlview: unsupported element type code %d", eltcode);
    }
}

/* ---------------------------------------------------------------------------
 * C_jlview_create — atomic pin + finalizer + ALTREP creation.
 *
 * Receives a JuliaObject (R external pointer wrapping a jl_value_t*) and
 * performs pin + extptr + finalizer atomically. No R-level window exists
 * between pin and finalizer registration.
 *
 * How JuliaCall stores Julia objects:
 *   JuliaCall's JuliaObject creates an R external pointer via
 *   RCall.makeExternalPtr(pointer_from_objref(Ref(x)), ...).
 *   The EXTPTRSXP address is a pointer to a Julia Ref{Any}.
 *   To recover the Julia value: dereference the Ref.
 *   In C: *(jl_value_t**)R_ExternalPtrAddr(sexp)
 * --------------------------------------------------------------------------- */
SEXP C_jlview_create(SEXP julia_array_sexp, SEXP writeable_sexp,
                     SEXP names_sexp, SEXP dimnames_sexp) {
    /* 1. Extract the jl_value_t* from JuliaCall's JuliaObject */
    void* ref_ptr = R_ExternalPtrAddr(julia_array_sexp);
    if (ref_ptr == NULL) {
        Rf_error("jlview: NULL Julia object");
    }
    jl_value_t* jl_array = *(jl_value_t**)ref_ptr;  /* deref the Ref */

    /* 2. Pin in Julia via C API — no R allocation, no longjmp */
    jl_value_t* pin_info = jl_call1_ptr(jl_pin_func, jl_array);
    if (jl_exception_occurred_ptr()) {
        /* pin failed — nothing to clean up, no R objects allocated yet */
        Rf_error("jlview: Julia pin failed");
    }

    /* 3. Extract fields from PinInfo struct via Julia C API */
    uint64_t pin_id   = jl_unbox_uint64_ptr(jl_get_field_ptr(pin_info, "id"));
    void*    ptr      = jl_unbox_voidpointer_ptr(jl_get_field_ptr(pin_info, "ptr"));
    int64_t  nbytes   = jl_unbox_int64_ptr(jl_get_field_ptr(pin_info, "nbytes"));
    int      eltcode  = (int)jl_unbox_int64_ptr(jl_get_field_ptr(pin_info, "eltype_code"));
    int      nd       = (int)jl_unbox_int64_ptr(jl_get_field_ptr(pin_info, "ndims"));

    /* Extract dims vector — jl_array_ptr returns a pointer to the raw
     * data of a Julia Vector{Int}. Int is Int64 on 64-bit systems. */
    jl_value_t* jl_dims = jl_get_field_ptr(pin_info, "dims");
    int64_t* dims_data = (int64_t*)jl_array_ptr_ptr(jl_dims);

    /* Check for any exceptions from field extraction */
    if (jl_exception_occurred_ptr()) {
        Rf_error("jlview: failed to extract PinInfo fields from Julia");
    }

    if (nd > 8) {
        Rf_error("jlview: arrays with more than 8 dimensions are not supported (got %d)", nd);
    }

    int64_t total_len = 1;
    int dims[8];
    for (int d = 0; d < nd; d++) {
        dims[d] = (int)dims_data[d];
        total_len *= dims[d];
    }

    /* 4. Create EXTPTRSXP and register finalizer IMMEDIATELY.
     *    Store pin_id in the tag for the finalizer to use.
     *    This is the critical safety boundary: from here onward, if anything
     *    longjmps, R GC will collect extptr and the finalizer unpins. */
    SEXP pin_id_tag = PROTECT(Rf_allocVector(RAWSXP, sizeof(uint64_t)));
    memcpy(RAW(pin_id_tag), &pin_id, sizeof(uint64_t));
    SEXP extptr = PROTECT(R_MakeExternalPtr(ptr, pin_id_tag, R_NilValue));
    R_RegisterCFinalizerEx(extptr, jlview_pointer_finalizer, TRUE);

    /* 5. Track allocation (may trigger R_gc, which is safe because
     *    R and Julia allocators are independent) */
    jlview_track_alloc((size_t)nbytes);

    /* 6. Build data2: VECSXP of length 3
     *    [[0]] = REALSXP length (scalar double — exact for integers up to 2^53,
     *            supports long vectors > 2^31 elements)
     *    [[1]] = INTSXP metadata: {is_writeable, eltcode}
     *    [[2]] = R_NilValue (cached materialized vector, filled on first
     *            Dataptr(TRUE) for non-writeable views) */
    int is_writeable = Rf_asLogical(writeable_sexp);

    SEXP len_sexp = PROTECT(Rf_ScalarReal((double)total_len));
    SEXP meta_int = PROTECT(Rf_allocVector(INTSXP, 2));
    INTEGER(meta_int)[0] = is_writeable;
    INTEGER(meta_int)[1] = eltcode;

    SEXP data2 = PROTECT(Rf_allocVector(VECSXP, 3));
    SET_VECTOR_ELT(data2, 0, len_sexp);
    SET_VECTOR_ELT(data2, 1, meta_int);
    SET_VECTOR_ELT(data2, 2, R_NilValue);

    /* 7. Create ALTREP object */
    SEXP result = PROTECT(R_new_altrep(
        select_class(eltcode), extptr, data2));

    /* 8. Set dim attribute if matrix/tensor (avoids extra JuliaCall round-trips) */
    if (nd >= 2) {
        SEXP rdims = PROTECT(Rf_allocVector(INTSXP, nd));
        for (int d = 0; d < nd; d++) {
            INTEGER(rdims)[d] = dims[d];
        }
        Rf_setAttrib(result, R_DimSymbol, rdims);
        UNPROTECT(1);
    }

    /* 9. Set names/dimnames atomically (refcount is 0 here — no COW) */
    if (dimnames_sexp != R_NilValue) {
        Rf_setAttrib(result, R_DimNamesSymbol, dimnames_sexp);
    }
    if (names_sexp != R_NilValue) {
        Rf_setAttrib(result, R_NamesSymbol, names_sexp);
    }

    /* 10. For non-writeable views, mark as not mutable so R always
     *     duplicates before [<- subassignment. This is a defensive measure:
     *     empirically R always duplicates ALTREP on [<- (due to refcount
     *     increment during generic dispatch), but MARK_NOT_MUTABLE makes
     *     the COW guarantee explicit and future-proof.
     *     For writeable views, leave the refcount natural — allowing direct
     *     writes to Julia memory when refcount=1 (the intended behavior). */
    if (!is_writeable) {
        MARK_NOT_MUTABLE(result);
    }

    UNPROTECT(6);  /* pin_id_tag, extptr, len_sexp, meta_int, data2, result */
    return result;
}
