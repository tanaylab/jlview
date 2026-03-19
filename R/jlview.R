#' Create a zero-copy R view of a Julia array
#'
#' Creates an ALTREP vector (or matrix, if 2D+) backed by Julia memory.
#' The resulting R object shares the same memory as the Julia array,
#' avoiding data copying. Modifications to the R object trigger
#' copy-on-write (unless `writeable = TRUE`).
#'
#' @param julia_array A JuliaObject referencing a Julia array
#' @param writeable If `TRUE`, allow R to write directly to Julia's memory.
#'   Use with caution — this enables shared mutation. Default `FALSE`.
#' @param names Optional character vector of names to attach to the result.
#'   Attached atomically during construction to avoid ALTREP materialization.
#' @param dimnames Optional list of dimnames to attach to the result.
#'   Attached atomically during construction to avoid ALTREP materialization.
#' @return An ALTREP vector backed by Julia memory, or a standard R vector
#'   if the Julia type is not supported for zero-copy.
#' @export
#' @examples
#' \dontrun{
#' JuliaCall::julia_setup()
#' # Create a Julia array and view it in R without copying
#' JuliaCall::julia_command("x = randn(1000)")
#' x <- jlview(JuliaCall::julia_eval("x"))
#' sum(x) # operates directly on Julia memory
#' }
jlview <- function(julia_array, writeable = FALSE, names = NULL, dimnames = NULL) {
    jlview_ensure_init()

    # Strip wrappers (ReadOnly, NamedArray, etc.)
    julia_array <- JuliaCall::julia_call(
        "JlviewSupport.unwrap", julia_array,
        need_return = "Julia"
    )

    # Check if type is supported for zero-copy
    support <- JuliaCall::julia_call(
        "JlviewSupport.check_support", julia_array,
        need_return = "R"
    )
    if (!support[[1]]) {
        warning(
            "jlview: type ", support[[2]],
            " not supported for zero-copy, copying"
        )
        return(JuliaCall::julia_call(
            "collect", julia_array,
            need_return = "R"
        ))
    }

    # Pin + create ALTREP atomically in C (no R-level window for leaks).
    # C_jlview_create calls jl_call1(pin, ...) internally, then immediately
    # registers the finalizer.
    # JuliaCall's JuliaObject stores the external pointer in the $id field
    # of an environment. We extract it here and pass the raw EXTPTRSXP to C.
    # Dims are set inside C from PinInfo — no extra JuliaCall round-trips.
    julia_extptr <- julia_array$id
    result <- .Call("C_jlview_create", julia_extptr, writeable, names, dimnames, PACKAGE = "jlview")

    return(result)
}
