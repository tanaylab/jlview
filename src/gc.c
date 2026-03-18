#include "jlview.h"

static size_t jlview_pinned_bytes = 0;
static size_t jlview_gc_threshold = 2ULL * 1024 * 1024 * 1024;  /* 2GB default */

void jlview_track_alloc(size_t nbytes) {
    jlview_pinned_bytes += nbytes;
    if (jlview_pinned_bytes > jlview_gc_threshold) {
        R_gc();  /* force R to collect stale ALTREP objects */
    }
}

void jlview_track_free(size_t nbytes) {
    if (nbytes <= jlview_pinned_bytes) {
        jlview_pinned_bytes -= nbytes;
    } else {
        jlview_pinned_bytes = 0;  /* underflow protection */
    }
}

/* R-callable: set the GC pressure threshold */
SEXP C_jlview_set_gc_threshold(SEXP bytes) {
    jlview_gc_threshold = (size_t)REAL(bytes)[0];
    return R_NilValue;
}

/* R-callable: get current pressure info */
SEXP C_jlview_gc_pressure(void) {
    SEXP result = PROTECT(Rf_allocVector(VECSXP, 2));
    SEXP names = PROTECT(Rf_allocVector(STRSXP, 2));

    SET_STRING_ELT(names, 0, Rf_mkChar("pinned_bytes"));
    SET_STRING_ELT(names, 1, Rf_mkChar("threshold"));

    SET_VECTOR_ELT(result, 0, Rf_ScalarReal((double)jlview_pinned_bytes));
    SET_VECTOR_ELT(result, 1, Rf_ScalarReal((double)jlview_gc_threshold));

    Rf_setAttrib(result, R_NamesSymbol, names);
    UNPROTECT(2);
    return result;
}
