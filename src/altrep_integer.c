#include "jlview.h"

/* This file DEFINES jlview_integer_class (declared extern in jlview.h) */
R_altrep_class_t jlview_integer_class;

/* Forward declaration — needed because Duplicate/Serialized_state call
 * Dataptr_or_null, which is defined in the ALTVEC section below. */
static const void* jlview_integer_Dataptr_or_null(SEXP x);

/* ===========================================================================
 * ALTREP methods
 * =========================================================================== */

static R_xlen_t jlview_integer_Length(SEXP x) {
    return (R_xlen_t)REAL(VECTOR_ELT(R_altrep_data2(x), 0))[0];
}

static Rboolean jlview_integer_Inspect(SEXP x, int pre, int deep, int pvec,
                                        void (*inspect_subtree)(SEXP, int, int, int)) {
    SEXP meta_list = R_altrep_data2(x);
    int is_writeable = INTEGER(VECTOR_ELT(meta_list, 1))[0];
    SEXP cached = VECTOR_ELT(meta_list, 2);
    int is_pinned = (R_ExternalPtrAddr(R_altrep_data1(x)) != NULL);
    Rprintf("jlview_integer (len=%lld, %s, %s%s)\n",
            (long long)jlview_integer_Length(x),
            is_writeable ? "writeable" : "read-only",
            is_pinned ? "pinned in Julia" : "released",
            cached != R_NilValue ? ", materialized" : "");
    return TRUE;
}

static SEXP jlview_integer_Duplicate(SEXP x, Rboolean deep) {
    R_xlen_t n = jlview_integer_Length(x);
    SEXP result = PROTECT(Rf_allocVector(INTSXP, n));
    const int* src = (const int*)jlview_integer_Dataptr_or_null(x);
    if (src == NULL) Rf_error("jlview: cannot copy — this object was released. Create a new view with jlview().");
    memcpy(INTEGER(result), src, n * sizeof(int));
    /* Copy attributes (dim, dimnames, names, class) from ALTREP to materialized vec */
    Rf_copyMostAttrib(x, result);
    UNPROTECT(1);
    return result;
}

static SEXP jlview_integer_Serialized_state(SEXP x) {
    /* Materialize into a standard R vector for serialization (saveRDS).
     * The serialized form is just a plain INTSXP — no custom unserialize needed. */
    return jlview_integer_Duplicate(x, TRUE);
}

/* ===========================================================================
 * ALTVEC methods
 * =========================================================================== */

/*
 * data2 layout: VECSXP of length 3
 *   [[0]] = REALSXP scalar: total element count (supports long vectors > 2^31)
 *   [[1]] = INTSXP metadata: {is_writeable, eltype_code}
 *   [[2]] = R_NilValue or cached materialized INTSXP (for COW on write)
 */

static void* jlview_integer_Dataptr(SEXP x, Rboolean writeable) {
    SEXP meta_list = R_altrep_data2(x);

    /* Once materialized, ALL access goes through the cache.
     * This ensures writes via Dataptr(TRUE) are visible to subsequent reads
     * via Elt/Dataptr_or_null/Dataptr(FALSE). */
    SEXP cached = VECTOR_ELT(meta_list, 2);
    if (cached != R_NilValue) return INTEGER(cached);

    SEXP extptr = R_altrep_data1(x);
    void* ptr = R_ExternalPtrAddr(extptr);
    if (ptr == NULL) {
        Rf_error("jlview: cannot access data — this object was released via jlview_release(). Create a new view with jlview().");
    }

    /* Return the Julia pointer for both read and write requests.
     * See altrep_real.c Dataptr for full rationale. In short: R's INTEGER(x)
     * calls Dataptr(TRUE) even for read-only ops (colSums, rowSums, etc.).
     * Materializing here would defeat zero-copy for all common operations.
     * R's [<- always duplicates ALTREP first, so writes never reach here. */
    return ptr;
}

static const void* jlview_integer_Dataptr_or_null(SEXP x) {
    /* If data has been materialized (via a prior Dataptr(TRUE) on a read-only
     * view), ALL subsequent reads must use the cache. Otherwise writes to the
     * cache are silently lost on the next read. */
    SEXP cached = VECTOR_ELT(R_altrep_data2(x), 2);
    if (cached != R_NilValue) return INTEGER(cached);

    SEXP extptr = R_altrep_data1(x);
    return R_ExternalPtrAddr(extptr);  /* returns NULL if released */
}

/* ===========================================================================
 * ALTINTEGER methods
 * =========================================================================== */

static int jlview_integer_Elt(SEXP x, R_xlen_t i) {
    const int* ptr = (const int*)jlview_integer_Dataptr_or_null(x);
    if (ptr == NULL) Rf_error("jlview: cannot access data — this object was released via jlview_release(). Create a new view with jlview().");
    return ptr[i];
}

static R_xlen_t jlview_integer_Get_region(SEXP x, R_xlen_t i, R_xlen_t n, int* buf) {
    const int* ptr = (const int*)jlview_integer_Dataptr_or_null(x);
    if (ptr == NULL) Rf_error("jlview: cannot access data — this object was released via jlview_release(). Create a new view with jlview().");
    R_xlen_t len = jlview_integer_Length(x);
    R_xlen_t ncopy = (i + n > len) ? len - i : n;
    memcpy(buf, ptr + i, ncopy * sizeof(int));
    return ncopy;
}

/* NOTE: No No_NA method for integer. NA_integer_ is INT_MIN (== -2147483648),
 * which is a valid Julia Int32 value. We cannot guarantee Julia data does not
 * contain INT_MIN, so we must let R perform NA checks. */

static SEXP jlview_integer_Unserialize_state(SEXP class, SEXP state) {
    /* The serialized state IS a standard INTSXP vector (see Serialized_state).
     * On deserialization, return it as-is — no ALTREP reconstruction needed.
     * This makes the deserialized object a plain R vector, not a jlview. */
    return state;
}

/* ===========================================================================
 * Registration
 * =========================================================================== */

void jlview_init_integer_class(DllInfo* dll) {
    jlview_integer_class = R_make_altinteger_class("jlview_integer", "jlview", dll);

    /* ALTREP */
    R_set_altrep_Length_method(jlview_integer_class, jlview_integer_Length);
    R_set_altrep_Inspect_method(jlview_integer_class, jlview_integer_Inspect);
    R_set_altrep_Duplicate_method(jlview_integer_class, jlview_integer_Duplicate);
    R_set_altrep_Serialized_state_method(jlview_integer_class, jlview_integer_Serialized_state);
    R_set_altrep_Unserialize_method(jlview_integer_class, jlview_integer_Unserialize_state);

    /* ALTVEC */
    R_set_altvec_Dataptr_method(jlview_integer_class, jlview_integer_Dataptr);
    R_set_altvec_Dataptr_or_null_method(jlview_integer_class, jlview_integer_Dataptr_or_null);

    /* ALTINTEGER */
    R_set_altinteger_Elt_method(jlview_integer_class, jlview_integer_Elt);
    R_set_altinteger_Get_region_method(jlview_integer_class, jlview_integer_Get_region);
}
