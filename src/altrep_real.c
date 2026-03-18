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
    if (src == NULL) Rf_error("jlview: data has been released");
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
        Rf_error("jlview: data has been released (use jlview_release() only when done)");
    }

    /* If writeable requested on a read-only view, we must NOT let R write
     * into Julia's memory. Materialize into a cached R vector.
     * (R's COW only calls Duplicate when refcount > 1. When refcount == 1,
     *  R calls Dataptr(TRUE) and writes directly. We must intercept this.) */
    int is_writeable = INTEGER(VECTOR_ELT(meta_list, 1))[0];

    if (writeable && !is_writeable) {
        /* Materialize: allocate R vector, copy data, cache in data2 */
        R_xlen_t n = jlview_real_Length(x);
        cached = PROTECT(Rf_allocVector(REALSXP, n));
        memcpy(REAL(cached), ptr, n * sizeof(double));
        SET_VECTOR_ELT(meta_list, 2, cached);
        UNPROTECT(1);
        return REAL(cached);
    }

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
    if (ptr == NULL) Rf_error("jlview: data has been released");
    return ptr[i];
}

static R_xlen_t jlview_real_Get_region(SEXP x, R_xlen_t i, R_xlen_t n, double* buf) {
    const double* ptr = (const double*)jlview_real_Dataptr_or_null(x);
    if (ptr == NULL) Rf_error("jlview: data has been released");
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
}
