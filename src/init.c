#include "jlview.h"

/* ===========================================================================
 * .Call method registration table
 * =========================================================================== */

static const R_CallMethodDef callMethods[] = {
    {"C_jlview_init_runtime",     (DL_FUNC) &C_jlview_init_runtime,     0},
    {"C_jlview_shutdown",         (DL_FUNC) &C_jlview_shutdown,         0},
    {"C_jlview_create",           (DL_FUNC) &C_jlview_create,           4},
    {"C_jlview_release",          (DL_FUNC) &C_jlview_release,          1},
    {"C_is_jlview",               (DL_FUNC) &C_is_jlview,               1},
    {"C_jlview_info",             (DL_FUNC) &C_jlview_info,             1},
    {"C_jlview_set_gc_threshold", (DL_FUNC) &C_jlview_set_gc_threshold, 1},
    {"C_jlview_gc_pressure",      (DL_FUNC) &C_jlview_gc_pressure,      0},
    {NULL, NULL, 0}
};

/* ===========================================================================
 * R_init_jlview — package initialization
 *
 * Called by R when the shared library is loaded. Registers:
 *   1. All .Call entry points (with fixed argument counts for safety)
 *   2. ALTREP classes (jlview_real for now; integer/raw in later phases)
 *
 * Dynamic symbol lookup is disabled (R_useDynamicSymbols = FALSE) so that
 * only registered routines are callable — required for CRAN and prevents
 * accidental symbol collisions.
 * =========================================================================== */
void R_init_jlview(DllInfo* dll) {
    R_registerRoutines(dll, NULL, callMethods, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);

    /* Register ALTREP classes — must happen at load time (DllInfo* required) */
    jlview_init_real_class(dll);
    jlview_init_integer_class(dll);
}

/* ===========================================================================
 * C_is_jlview — check whether an R object is a jlview ALTREP vector
 *
 * Strategy: check ALTREP bit, then verify the internal structure matches
 * jlview's 3-slot layout:
 *   data1 = EXTPTRSXP (Julia data pointer + pin_id tag)
 *   data2 = VECSXP of length 3 (length, metadata, cache)
 *
 * This is a pragmatic structural check. With only one ALTREP class
 * registered (jlview_real), false positives from other ALTREP packages
 * are extremely unlikely — no other package uses this exact layout.
 * =========================================================================== */
SEXP C_is_jlview(SEXP x) {
    if (!ALTREP(x)) return Rf_ScalarLogical(FALSE);

    /* Check data1 is an external pointer (our Julia data ptr wrapper) */
    SEXP data1 = R_altrep_data1(x);
    if (TYPEOF(data1) != EXTPTRSXP) return Rf_ScalarLogical(FALSE);

    /* Check data2 has our expected 3-slot VECSXP structure */
    SEXP data2 = R_altrep_data2(x);
    if (TYPEOF(data2) != VECSXP || XLENGTH(data2) != 3)
        return Rf_ScalarLogical(FALSE);

    /* Verify metadata slot has expected structure */
    SEXP meta = VECTOR_ELT(data2, 1);
    if (TYPEOF(meta) != INTSXP || XLENGTH(meta) != 2)
        return Rf_ScalarLogical(FALSE);

    /* Verify eltcode is a known jlview type */
    int eltcode = INTEGER(meta)[1];
    if (eltcode != JLVIEW_FLOAT64 && eltcode != JLVIEW_INT32)
        return Rf_ScalarLogical(FALSE);

    return Rf_ScalarLogical(TRUE);
}

/* ===========================================================================
 * C_jlview_info — return diagnostic information about a jlview object
 *
 * Returns a named list with:
 *   type         : Julia element type name (e.g. "Float64")
 *   length       : total element count (as double, for long vector support)
 *   writeable    : logical — was this created with writeable=TRUE?
 *   released     : logical — has the Julia pointer been released/finalized?
 *   materialized : logical — has a COW copy been made into R memory?
 * =========================================================================== */
SEXP C_jlview_info(SEXP x) {
    if (!ALTREP(x)) Rf_error("not a jlview object");

    SEXP data2 = R_altrep_data2(x);
    SEXP extptr = R_altrep_data1(x);

    R_xlen_t len = (R_xlen_t)REAL(VECTOR_ELT(data2, 0))[0];
    int is_writeable = INTEGER(VECTOR_ELT(data2, 1))[0];
    int eltcode = INTEGER(VECTOR_ELT(data2, 1))[1];
    int released = (R_ExternalPtrAddr(extptr) == NULL);
    int materialized = (VECTOR_ELT(data2, 2) != R_NilValue);

    const char* type_str;
    switch (eltcode) {
    case JLVIEW_FLOAT64: type_str = "Float64"; break;
    case JLVIEW_INT32:   type_str = "Int32";   break;
    default:             type_str = "unknown";  break;
    }

    SEXP result = PROTECT(Rf_allocVector(VECSXP, 5));
    SEXP names  = PROTECT(Rf_allocVector(STRSXP, 5));

    SET_STRING_ELT(names, 0, Rf_mkChar("type"));
    SET_STRING_ELT(names, 1, Rf_mkChar("length"));
    SET_STRING_ELT(names, 2, Rf_mkChar("writeable"));
    SET_STRING_ELT(names, 3, Rf_mkChar("released"));
    SET_STRING_ELT(names, 4, Rf_mkChar("materialized"));

    SET_VECTOR_ELT(result, 0, Rf_mkString(type_str));
    SET_VECTOR_ELT(result, 1, Rf_ScalarReal((double)len));
    SET_VECTOR_ELT(result, 2, Rf_ScalarLogical(is_writeable));
    SET_VECTOR_ELT(result, 3, Rf_ScalarLogical(released));
    SET_VECTOR_ELT(result, 4, Rf_ScalarLogical(materialized));

    Rf_setAttrib(result, R_NamesSymbol, names);
    UNPROTECT(2);
    return result;
}
