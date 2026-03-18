#ifndef JLVIEW_H
#define JLVIEW_H

#include <R.h>
#include <Rinternals.h>
#include <R_ext/Altrep.h>
#include <R_ext/Rdynload.h>
#include <dlfcn.h>
#include <stdint.h>
#include <unistd.h>
#include <string.h>

/* Julia value type — opaque pointer, no Julia headers needed */
typedef void* jl_value_t;

/* ---------------------------------------------------------------------------
 * Julia C API function pointers
 *
 * These are DEFINED in finalizer.c and resolved at runtime via dlsym()
 * in C_jlview_init_runtime(). JuliaCall loads libjulia with RTLD_GLOBAL,
 * making all Julia C API symbols globally visible.
 * --------------------------------------------------------------------------- */
extern jl_value_t* (*jl_eval_string_ptr)(const char*);
extern jl_value_t* (*jl_call1_ptr)(jl_value_t*, jl_value_t*);
extern jl_value_t* (*jl_box_uint64_ptr)(uint64_t);
extern int64_t     (*jl_unbox_int64_ptr)(jl_value_t*);
extern uint64_t    (*jl_unbox_uint64_ptr)(jl_value_t*);
extern void*       (*jl_unbox_voidpointer_ptr)(jl_value_t*);
extern jl_value_t* (*jl_get_field_ptr)(jl_value_t*, const char*);
extern jl_value_t* (*jl_exception_occurred_ptr)(void);
extern void*       (*jl_array_ptr_ptr)(jl_value_t*);

/* ---------------------------------------------------------------------------
 * LOAD_JL_SYMBOL — resolve a Julia C API symbol at runtime
 *
 * var:  function pointer variable to populate
 * name: string name of the symbol (e.g. "jl_eval_string")
 * --------------------------------------------------------------------------- */
#define LOAD_JL_SYMBOL(var, name) do { \
    void* sym_ = dlsym(RTLD_DEFAULT, name); \
    if (sym_ == NULL) { \
        Rf_error("jlview: failed to resolve Julia symbol '%s'. " \
                 "Is julia_setup() initialized?", name); \
    } \
    memcpy(&(var), &sym_, sizeof(var)); \
} while(0)

/* ---------------------------------------------------------------------------
 * Element type codes — used in metadata slot to identify Julia source type
 * --------------------------------------------------------------------------- */
#define JLVIEW_FLOAT64 1
#define JLVIEW_INT32   2
#define JLVIEW_UINT8   3

/* ---------------------------------------------------------------------------
 * Shared state (defined in their respective .c files)
 * --------------------------------------------------------------------------- */
extern R_altrep_class_t jlview_real_class;
extern jl_value_t* jl_pin_func;
extern jl_value_t* jl_unpin_func;
extern int jlview_julia_is_alive;
extern pid_t jlview_init_pid;

/* ---------------------------------------------------------------------------
 * ALTREP class registration
 * --------------------------------------------------------------------------- */
void jlview_init_real_class(DllInfo* dll);

/* ---------------------------------------------------------------------------
 * GC pressure tracking
 * --------------------------------------------------------------------------- */
void jlview_track_alloc(size_t nbytes);
void jlview_track_free(size_t nbytes);

/* ---------------------------------------------------------------------------
 * Pointer finalizer — unpins Julia array when R external pointer is collected
 * --------------------------------------------------------------------------- */
void jlview_pointer_finalizer(SEXP extptr);

/* ---------------------------------------------------------------------------
 * .Call entry points
 * --------------------------------------------------------------------------- */
SEXP C_jlview_init_runtime(void);
SEXP C_jlview_shutdown(void);
SEXP C_jlview_create(SEXP julia_array_sexp, SEXP writeable_sexp);
SEXP C_jlview_release(SEXP x);
SEXP C_is_jlview(SEXP x);
SEXP C_jlview_info(SEXP x);
SEXP C_jlview_set_gc_threshold(SEXP bytes);
SEXP C_jlview_gc_pressure(void);

#endif /* JLVIEW_H */
