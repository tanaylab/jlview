#ifndef JLVIEW_H
#define JLVIEW_H

#include <R.h>
#include <Rinternals.h>
#include <R_ext/Altrep.h>
#include <R_ext/Rdynload.h>
#include <stdint.h>
#include <string.h>

/* Platform-specific includes for dynamic symbol resolution and getpid() */
#ifdef _WIN32
#include <windows.h>
#include <process.h>
#else
#include <dlfcn.h>
#include <unistd.h>
#endif

/* Julia value type — opaque pointer, no Julia headers needed */
typedef void* jl_value_t;

/* ---------------------------------------------------------------------------
 * Julia C API function pointers
 *
 * These are DEFINED in finalizer.c and resolved at runtime via
 * dlsym() (Unix) or GetProcAddress() (Windows) in C_jlview_init_runtime().
 * JuliaCall loads libjulia, making these symbols available.
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
 *
 * Unix:    dlsym(RTLD_DEFAULT, ...) — JuliaCall loads libjulia with RTLD_GLOBAL
 * Windows: GetProcAddress on libjulia.dll module handle
 * --------------------------------------------------------------------------- */
#ifdef _WIN32

/* jl_module_handle is defined in finalizer.c (the only file that
 * calls LOAD_JL_SYMBOL). Declared extern here to keep the macro
 * out of other translation units and avoid unused-function warnings. */
extern HMODULE jl_module_handle;
void jlview_ensure_jl_module(void);

#define LOAD_JL_SYMBOL(var, name) do { \
    jlview_ensure_jl_module(); \
    FARPROC sym_ = GetProcAddress(jl_module_handle, name); \
    if (sym_ == NULL) { \
        Rf_error("jlview: failed to resolve Julia symbol '%s'. " \
                 "Is julia_setup() initialized?", name); \
    } \
    memcpy(&(var), &sym_, sizeof(var)); \
} while(0)

#else /* Unix */

#define LOAD_JL_SYMBOL(var, name) do { \
    void* sym_ = dlsym(RTLD_DEFAULT, name); \
    if (sym_ == NULL) { \
        Rf_error("jlview: failed to resolve Julia symbol '%s'. " \
                 "Is julia_setup() initialized?", name); \
    } \
    memcpy(&(var), &sym_, sizeof(var)); \
} while(0)

#endif /* _WIN32 */

/* ---------------------------------------------------------------------------
 * Element type codes — used in metadata slot to identify Julia source type
 * --------------------------------------------------------------------------- */
#define JLVIEW_FLOAT64 1
#define JLVIEW_INT32   2
/* UInt8 arrays are converted to Int32 in Julia before reaching C — no UINT8 code needed */

/* ---------------------------------------------------------------------------
 * Shared state (defined in their respective .c files)
 * --------------------------------------------------------------------------- */
extern R_altrep_class_t jlview_real_class;
extern R_altrep_class_t jlview_integer_class;
extern jl_value_t* jl_pin_func;
extern jl_value_t* jl_unpin_func;
extern jl_value_t* jl_sum_func;
extern jl_value_t* jl_minimum_func;
extern jl_value_t* jl_maximum_func;
extern double (*jl_unbox_float64_ptr)(jl_value_t*);
extern int jlview_julia_is_alive;
extern pid_t jlview_init_pid;

/* ---------------------------------------------------------------------------
 * ALTREP class registration
 * --------------------------------------------------------------------------- */
void jlview_init_real_class(DllInfo* dll);
void jlview_init_integer_class(DllInfo* dll);

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
SEXP C_jlview_create(SEXP julia_array_sexp, SEXP writeable_sexp,
                     SEXP names_sexp, SEXP dimnames_sexp);
SEXP C_jlview_release(SEXP x);
SEXP C_is_jlview(SEXP x);
SEXP C_jlview_info(SEXP x);
SEXP C_jlview_set_gc_threshold(SEXP bytes);
SEXP C_jlview_gc_pressure(void);
#endif /* JLVIEW_H */
