#include "jlview.h"

/* This file DEFINES jlview_real_class (declared extern in jlview.h) */
R_altrep_class_t jlview_real_class;

/* Forward declaration — needed because Duplicate/Serialized_state call
 * Dataptr_or_null, which is defined in the ALTVEC section below. */
static const void* jlview_real_Dataptr_or_null(SEXP x);

/* ===========================================================================
 * ALTREP methods
 * =========================================================================== */

static R_xlen_t jlview_real_Length(SEXP x) {
    return (R_xlen_t)REAL(VECTOR_ELT(R_altrep_data2(x), 0))[0];
}

static Rboolean jlview_real_Inspect(SEXP x, int pre, int deep, int pvec,
                                     void (*inspect_subtree)(SEXP, int, int, int)) {
    SEXP meta_list = R_altrep_data2(x);
    int is_writeable = INTEGER(VECTOR_ELT(meta_list, 1))[0];
    SEXP cached = VECTOR_ELT(meta_list, 2);
    int is_pinned = (R_ExternalPtrAddr(R_altrep_data1(x)) != NULL);
    Rprintf("jlview_real (len=%lld, %s, %s%s)\n",
            (long long)jlview_real_Length(x),
            is_writeable ? "writeable" : "read-only",
            is_pinned ? "pinned in Julia" : "released",
            cached != R_NilValue ? ", materialized" : "");
    return TRUE;
}

static SEXP jlview_real_Duplicate(SEXP x, Rboolean deep) {
    R_xlen_t n = jlview_real_Length(x);
    SEXP result = PROTECT(Rf_allocVector(REALSXP, n));
    const double* src = (const double*)jlview_real_Dataptr_or_null(x);
    if (src == NULL) Rf_error("jlview: cannot copy — this object was released. Create a new view with jlview().");
    memcpy(REAL(result), src, n * sizeof(double));
    /* Copy attributes (dim, dimnames, names, class) from ALTREP to materialized vec */
    Rf_copyMostAttrib(x, result);
    UNPROTECT(1);
    return result;
}

static SEXP jlview_real_Serialized_state(SEXP x) {
    /* Materialize into a standard R vector for serialization (saveRDS).
     * The serialized form is just a plain REALSXP — no custom unserialize needed. */
    return jlview_real_Duplicate(x, TRUE);
}

/* ===========================================================================
 * ALTVEC methods
 * =========================================================================== */

/*
 * data2 layout: VECSXP of length 3
 *   [[0]] = REALSXP scalar: total element count (supports long vectors > 2^31)
 *   [[1]] = INTSXP metadata: {is_writeable, eltype_code}
 *   [[2]] = R_NilValue or cached materialized REALSXP (for COW on write)
 */

static void* jlview_real_Dataptr(SEXP x, Rboolean writeable) {
    SEXP meta_list = R_altrep_data2(x);

    /* Once materialized, ALL access goes through the cache.
     * This ensures writes via Dataptr(TRUE) are visible to subsequent reads
     * via Elt/Dataptr_or_null/Dataptr(FALSE). */
    SEXP cached = VECTOR_ELT(meta_list, 2);
    if (cached != R_NilValue) return REAL(cached);

    SEXP extptr = R_altrep_data1(x);
    void* ptr = R_ExternalPtrAddr(extptr);
    if (ptr == NULL) {
        Rf_error("jlview: cannot access data — this object was released via jlview_release(). Create a new view with jlview().");
    }

    /* Return the Julia pointer for both read and write requests.
     *
     * R's REAL(x) macro calls Dataptr(x, TRUE) — requesting writeable access —
     * even for read-only operations like colSums, rowSums, colMeans, apply, %*%.
     * If we materialized on Dataptr(TRUE), these common operations would copy
     * the entire array into R's heap, defeating zero-copy.
     *
     * Safety for non-writeable views: C_jlview_create calls MARK_NOT_MUTABLE
     * on non-writeable ALTREP objects, which sets refcount to REFCNTMAX. This
     * ensures MAYBE_SHARED() always returns TRUE, so R's [<- always calls
     * Duplicate() before writing — Julia memory is never mutated.
     *
     * For writeable views: refcount is left natural. When refcount=1, R's [<-
     * may write directly through this pointer to Julia memory, which is the
     * intended shared-mutation behavior for writeable=TRUE. */
    return ptr;
}

static const void* jlview_real_Dataptr_or_null(SEXP x) {
    /* If data has been materialized (via a prior Dataptr(TRUE) on a read-only
     * view), ALL subsequent reads must use the cache. Otherwise writes to the
     * cache are silently lost on the next read. */
    SEXP cached = VECTOR_ELT(R_altrep_data2(x), 2);
    if (cached != R_NilValue) return REAL(cached);

    SEXP extptr = R_altrep_data1(x);
    return R_ExternalPtrAddr(extptr);  /* returns NULL if released */
}

/* ===========================================================================
 * ALTREAL methods
 * =========================================================================== */

static double jlview_real_Elt(SEXP x, R_xlen_t i) {
    const double* ptr = (const double*)jlview_real_Dataptr_or_null(x);
    if (ptr == NULL) Rf_error("jlview: cannot access data — this object was released via jlview_release(). Create a new view with jlview().");
    return ptr[i];
}

static R_xlen_t jlview_real_Get_region(SEXP x, R_xlen_t i, R_xlen_t n, double* buf) {
    const double* ptr = (const double*)jlview_real_Dataptr_or_null(x);
    if (ptr == NULL) Rf_error("jlview: cannot access data — this object was released via jlview_release(). Create a new view with jlview().");
    R_xlen_t len = jlview_real_Length(x);
    R_xlen_t ncopy = (i + n > len) ? len - i : n;
    memcpy(buf, ptr + i, ncopy * sizeof(double));
    return ncopy;
}

/* Julia Float64 arrays cannot contain R's NA_real_ (a specific NaN bit pattern)
 * through normal computation. Declaring No_NA = TRUE lets R skip NA checks in
 * sum(), mean(), min(), max(), etc. — a significant performance win.
 *
 * However, after COW materialization (user wrote to a non-writeable view),
 * the cache is a standard R vector that may now contain NA_real_ (the user
 * could have written NA). In that case, return 0 so R performs NA checks. */
static int jlview_real_No_NA(SEXP x) {
    SEXP cached = VECTOR_ELT(R_altrep_data2(x), 2);
    if (cached != R_NilValue) return 0;  /* materialized — user may have written NAs */
    return 1;  /* unmaterialized Julia data has no R-style NAs */
}

/* ===========================================================================
 * ALTREAL Summary methods — Sum, Min, Max
 *
 * These call Julia directly on the pinned array, avoiding materialization.
 * Return NULL to fall back to R's default if anything is unavailable.
 * =========================================================================== */

static SEXP jlview_real_Sum(SEXP x, Rboolean narm) {
    /* If materialized, fall back to R's default (cache may contain NAs) */
    SEXP cached = VECTOR_ELT(R_altrep_data2(x), 2);
    if (cached != R_NilValue) return NULL;

    SEXP extptr = R_altrep_data1(x);
    if (R_ExternalPtrAddr(extptr) == NULL) return NULL;

    SEXP pin_id_sexp = R_ExternalPtrTag(extptr);
    if (pin_id_sexp == R_NilValue) return NULL;
    uint64_t pin_id;
    memcpy(&pin_id, RAW(pin_id_sexp), sizeof(uint64_t));

    if (!jlview_julia_is_alive || jl_sum_func == NULL) return NULL;

    jl_value_t* jl_id = jl_box_uint64_ptr(pin_id);
    jl_value_t* result = jl_call1_ptr(jl_sum_func, jl_id);
    if (jl_exception_occurred_ptr()) return NULL;

    double val = jl_unbox_float64_ptr(result);
    return Rf_ScalarReal(val);
}

static SEXP jlview_real_Min(SEXP x, Rboolean narm) {
    SEXP cached = VECTOR_ELT(R_altrep_data2(x), 2);
    if (cached != R_NilValue) return NULL;

    SEXP extptr = R_altrep_data1(x);
    if (R_ExternalPtrAddr(extptr) == NULL) return NULL;

    SEXP pin_id_sexp = R_ExternalPtrTag(extptr);
    if (pin_id_sexp == R_NilValue) return NULL;
    uint64_t pin_id;
    memcpy(&pin_id, RAW(pin_id_sexp), sizeof(uint64_t));

    if (!jlview_julia_is_alive || jl_minimum_func == NULL) return NULL;

    jl_value_t* jl_id = jl_box_uint64_ptr(pin_id);
    jl_value_t* result = jl_call1_ptr(jl_minimum_func, jl_id);
    if (jl_exception_occurred_ptr()) return NULL;

    double val = jl_unbox_float64_ptr(result);
    return Rf_ScalarReal(val);
}

static SEXP jlview_real_Max(SEXP x, Rboolean narm) {
    SEXP cached = VECTOR_ELT(R_altrep_data2(x), 2);
    if (cached != R_NilValue) return NULL;

    SEXP extptr = R_altrep_data1(x);
    if (R_ExternalPtrAddr(extptr) == NULL) return NULL;

    SEXP pin_id_sexp = R_ExternalPtrTag(extptr);
    if (pin_id_sexp == R_NilValue) return NULL;
    uint64_t pin_id;
    memcpy(&pin_id, RAW(pin_id_sexp), sizeof(uint64_t));

    if (!jlview_julia_is_alive || jl_maximum_func == NULL) return NULL;

    jl_value_t* jl_id = jl_box_uint64_ptr(pin_id);
    jl_value_t* result = jl_call1_ptr(jl_maximum_func, jl_id);
    if (jl_exception_occurred_ptr()) return NULL;

    double val = jl_unbox_float64_ptr(result);
    return Rf_ScalarReal(val);
}

static SEXP jlview_real_Unserialize_state(SEXP class, SEXP state) {
    /* The serialized state IS a standard REALSXP vector (see Serialized_state).
     * On deserialization, return it as-is — no ALTREP reconstruction needed.
     * This makes the deserialized object a plain R vector, not a jlview. */
    return state;
}

/* ===========================================================================
 * Registration
 * =========================================================================== */

void jlview_init_real_class(DllInfo* dll) {
    jlview_real_class = R_make_altreal_class("jlview_real", "jlview", dll);

    /* ALTREP */
    R_set_altrep_Length_method(jlview_real_class, jlview_real_Length);
    R_set_altrep_Inspect_method(jlview_real_class, jlview_real_Inspect);
    R_set_altrep_Duplicate_method(jlview_real_class, jlview_real_Duplicate);
    R_set_altrep_Serialized_state_method(jlview_real_class, jlview_real_Serialized_state);
    R_set_altrep_Unserialize_method(jlview_real_class, jlview_real_Unserialize_state);

    /* ALTVEC */
    R_set_altvec_Dataptr_method(jlview_real_class, jlview_real_Dataptr);
    R_set_altvec_Dataptr_or_null_method(jlview_real_class, jlview_real_Dataptr_or_null);

    /* ALTREAL */
    R_set_altreal_Elt_method(jlview_real_class, jlview_real_Elt);
    R_set_altreal_Get_region_method(jlview_real_class, jlview_real_Get_region);
    R_set_altreal_No_NA_method(jlview_real_class, jlview_real_No_NA);
    R_set_altreal_Sum_method(jlview_real_class, jlview_real_Sum);
    R_set_altreal_Min_method(jlview_real_class, jlview_real_Min);
    R_set_altreal_Max_method(jlview_real_class, jlview_real_Max);
}
