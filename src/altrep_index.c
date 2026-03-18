#include "jlview.h"

/* This file DEFINES jlview_index_class (declared extern in jlview.h) */
R_altrep_class_t jlview_index_class;

/* ===========================================================================
 * Layout:
 *   data1 = EXTPTRSXP wrapping raw Julia index data pointer
 *           Tag       = REALSXP scalar: pin_id (for finalizer)
 *           Protected = INTSXP(2): {length, src_is_int64}
 *   data2 = R_NilValue (initially) or cached materialized INTSXP (shifted)
 *
 * This ALTINTEGER class is specialized for sparse matrix indices (CSC p/i).
 * Julia uses 1-based indexing; R CSC format uses 0-based. Every element
 * returned is shifted by -1 relative to the Julia source.
 * =========================================================================== */

/* Forward declaration — Duplicate/Serialized_state need Dataptr_or_null */
static const void* jlview_index_Dataptr_or_null(SEXP x);

/* ===========================================================================
 * ALTREP methods
 * =========================================================================== */

static R_xlen_t jlview_index_Length(SEXP x) {
    SEXP extptr = R_altrep_data1(x);
    SEXP prot = R_ExternalPtrProtected(extptr);
    return (R_xlen_t)INTEGER(prot)[0];
}

static Rboolean jlview_index_Inspect(SEXP x, int pre, int deep, int pvec,
                                      void (*inspect_subtree)(SEXP, int, int, int)) {
    SEXP extptr = R_altrep_data1(x);
    SEXP prot = R_ExternalPtrProtected(extptr);
    int is_int64 = INTEGER(prot)[1];
    SEXP cached = R_altrep_data2(x);
    int is_pinned = (R_ExternalPtrAddr(extptr) != NULL);
    Rprintf("jlview_index (len=%d, %s, %s%s)\n",
            INTEGER(prot)[0],
            is_int64 ? "Int64" : "Int32",
            is_pinned ? "pinned" : "released",
            cached != R_NilValue ? ", materialized" : "");
    return TRUE;
}

static SEXP jlview_index_Duplicate(SEXP x, Rboolean deep) {
    R_xlen_t n = jlview_index_Length(x);
    SEXP result = PROTECT(Rf_allocVector(INTSXP, n));

    /* If already materialized, copy from cache; otherwise shift from source */
    const int* cached = (const int*)jlview_index_Dataptr_or_null(x);
    if (cached != NULL) {
        memcpy(INTEGER(result), cached, n * sizeof(int));
    } else {
        /* Source released and no cache — error */
        Rf_error("jlview_index: data has been released");
    }

    Rf_copyMostAttrib(x, result);
    UNPROTECT(1);
    return result;
}

static SEXP jlview_index_Serialized_state(SEXP x) {
    return jlview_index_Duplicate(x, TRUE);
}

static SEXP jlview_index_Unserialize_state(SEXP class, SEXP state) {
    return state;
}

/* ===========================================================================
 * ALTINTEGER methods
 * =========================================================================== */

static int jlview_index_Elt(SEXP x, R_xlen_t i) {
    /* If materialized, use the cache */
    SEXP cached = R_altrep_data2(x);
    if (cached != R_NilValue) {
        return INTEGER(cached)[i];
    }

    /* Read from Julia source with -1 shift */
    SEXP extptr = R_altrep_data1(x);
    void* ptr = R_ExternalPtrAddr(extptr);
    if (ptr == NULL) Rf_error("jlview_index: data has been released");

    SEXP prot = R_ExternalPtrProtected(extptr);
    int is_int64 = INTEGER(prot)[1];

    if (is_int64) {
        int64_t* p = (int64_t*)ptr;
        return (int)(p[i] - 1);
    } else {
        int32_t* p = (int32_t*)ptr;
        return p[i] - 1;
    }
}

static R_xlen_t jlview_index_Get_region(SEXP x, R_xlen_t i, R_xlen_t n, int* buf) {
    R_xlen_t len = jlview_index_Length(x);
    R_xlen_t ncopy = (i + n > len) ? len - i : n;
    for (R_xlen_t k = 0; k < ncopy; k++) {
        buf[k] = jlview_index_Elt(x, i + k);
    }
    return ncopy;
}

/* ===========================================================================
 * ALTVEC methods
 * =========================================================================== */

static const void* jlview_index_Dataptr_or_null(SEXP x) {
    SEXP cached = R_altrep_data2(x);
    if (cached != R_NilValue) return INTEGER(cached);
    return NULL;  /* values need shifting — cannot return raw pointer */
}

static void* jlview_index_Dataptr(SEXP x, Rboolean writeable) {
    /* If already materialized, return the cache */
    SEXP cached = R_altrep_data2(x);
    if (cached != R_NilValue) return INTEGER(cached);

    /* Lazy materialization: allocate INTSXP, shift all elements, cache */
    R_xlen_t n = jlview_index_Length(x);
    cached = PROTECT(Rf_allocVector(INTSXP, n));
    int* out = INTEGER(cached);
    for (R_xlen_t i = 0; i < n; i++) {
        out[i] = jlview_index_Elt(x, i);
    }
    R_set_altrep_data2(x, cached);
    UNPROTECT(1);
    return INTEGER(cached);
}

/* ===========================================================================
 * Eager materialization (.Call entry point)
 * =========================================================================== */

SEXP C_jlview_index_materialize(SEXP x) {
    jlview_index_Dataptr(x, FALSE);
    return R_NilValue;
}

/* ===========================================================================
 * C_jlview_create_index — create ALTREP index from Julia sparse index array
 *
 * Arguments:
 *   julia_extptr  : JuliaCall external pointer (Ref wrapping Julia array)
 *   pin_id_sexp   : REALSXP scalar with pin_id (already pinned on Julia side)
 *   length_sexp   : INTSXP or REALSXP scalar with element count
 *   is_int64_sexp : LGLSXP scalar — TRUE if Julia source is Int64
 * =========================================================================== */

SEXP C_jlview_create_index(SEXP julia_extptr, SEXP pin_id_sexp,
                            SEXP length_sexp, SEXP is_int64_sexp) {
    /* 1. Extract raw data pointer from JuliaCall's JuliaObject:
     *    R_ExternalPtrAddr gives pointer to Ref{Any};
     *    dereference to get jl_value_t* (the Julia Array);
     *    jl_array_ptr gives the raw data pointer. */
    void* ref_ptr = R_ExternalPtrAddr(julia_extptr);
    if (ref_ptr == NULL) {
        Rf_error("jlview_index: NULL Julia object");
    }
    jl_value_t* jl_array = *(jl_value_t**)ref_ptr;  /* deref the Ref */
    void* data_ptr = jl_array_ptr_ptr(jl_array);

    /* 2. Create EXTPTRSXP with the data pointer */
    int length = Rf_asInteger(length_sexp);
    int is_int64 = Rf_asLogical(is_int64_sexp);

    /* Protected = INTSXP(2): {length, src_is_int64} */
    SEXP prot = PROTECT(Rf_allocVector(INTSXP, 2));
    INTEGER(prot)[0] = length;
    INTEGER(prot)[1] = is_int64;

    /* Tag = REALSXP scalar with pin_id (for finalizer) */
    SEXP tag = PROTECT(Rf_ScalarReal(REAL(pin_id_sexp)[0]));

    SEXP extptr = PROTECT(R_MakeExternalPtr(data_ptr, tag, prot));

    /* 3. Register finalizer */
    R_RegisterCFinalizerEx(extptr, jlview_pointer_finalizer, TRUE);

    /* 4. Track allocation */
    size_t nbytes = (size_t)length * (is_int64 ? sizeof(int64_t) : sizeof(int32_t));
    jlview_track_alloc(nbytes);

    /* 5. Create ALTREP: data1 = extptr, data2 = R_NilValue (no cache yet) */
    SEXP result = PROTECT(R_new_altrep(jlview_index_class, extptr, R_NilValue));

    UNPROTECT(4);  /* prot, tag, extptr, result */
    return result;
}

/* ===========================================================================
 * Registration
 * =========================================================================== */

void jlview_init_index_class(DllInfo* dll) {
    jlview_index_class = R_make_altinteger_class("jlview_index", "jlview", dll);

    /* ALTREP */
    R_set_altrep_Length_method(jlview_index_class, jlview_index_Length);
    R_set_altrep_Inspect_method(jlview_index_class, jlview_index_Inspect);
    R_set_altrep_Duplicate_method(jlview_index_class, jlview_index_Duplicate);
    R_set_altrep_Serialized_state_method(jlview_index_class, jlview_index_Serialized_state);
    R_set_altrep_Unserialize_method(jlview_index_class, jlview_index_Unserialize_state);

    /* ALTVEC */
    R_set_altvec_Dataptr_method(jlview_index_class, jlview_index_Dataptr);
    R_set_altvec_Dataptr_or_null_method(jlview_index_class, jlview_index_Dataptr_or_null);

    /* ALTINTEGER */
    R_set_altinteger_Elt_method(jlview_index_class, jlview_index_Elt);
    R_set_altinteger_Get_region_method(jlview_index_class, jlview_index_Get_region);
}
