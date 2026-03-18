#' @useDynLib jlview
NULL

# Package-level state: has the Julia runtime been initialized?
jlview_env <- new.env(parent = emptyenv())
jlview_env$initialized <- FALSE

#' Initialize the jlview Julia runtime
#'
#' Called lazily on first use. Requires that JuliaCall::julia_setup()
#' has already been called.
#'
#' @keywords internal
#' @noRd
jlview_ensure_init <- function() {
    if (jlview_env$initialized) {
        return(invisible(NULL))
    }

    # Load the Julia support module
    jl_support_path <- system.file("julia", "jlview_support.jl", package = "jlview")
    if (jl_support_path == "") {
        stop("jlview: could not find jlview_support.jl")
    }

    # Include the Julia module (JuliaCall must already be initialized)
    JuliaCall::julia_command(paste0('include("', jl_support_path, '")'))

    # Initialize C runtime (resolve Julia symbols, cache function pointers)
    .Call("C_jlview_init_runtime", PACKAGE = "jlview")

    jlview_env$initialized <- TRUE
    invisible(NULL)
}

#' @keywords internal
#' @noRd
.onLoad <- function(libname, pkgname) {
    # Nothing to do here — Julia init is deferred to first use via jlview_ensure_init()
}

#' @keywords internal
#' @noRd
.onUnload <- function(libpath) {
    # Mark Julia as dead BEFORE final GC sweep (only if DLL is still loaded)
    if (is.loaded("C_jlview_shutdown", PACKAGE = "jlview")) {
        .Call("C_jlview_shutdown", PACKAGE = "jlview")
    }
    jlview_env$initialized <- FALSE
}
