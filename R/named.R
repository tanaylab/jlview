#' Create a zero-copy R view of a named Julia vector
#'
#' Creates a zero-copy ALTREP view of a Julia NamedArray vector,
#' preserving the axis names.
#'
#' @param julia_named_array A JuliaObject referencing a Julia NamedArray vector
#' @return An ALTREP vector with names set from the Julia NamedArray
#' @export
#' @examples
#' if (interactive()) {
#'     JuliaCall::julia_setup()
#'     JuliaCall::julia_command("using NamedArrays")
#'     v <- JuliaCall::julia_eval('NamedArray([1.0, 2.0, 3.0], (["a", "b", "c"],))')
#'     x <- jlview_named_vector(v)
#'     names(x) # returns c("a", "b", "c")
#' }
jlview_named_vector <- function(julia_named_array) {
    jlview_ensure_init()

    # Get names before stripping wrapper
    names_vec <- JuliaCall::julia_call(
        "NamedArrays.names", julia_named_array, 1L,
        need_return = "R"
    )

    # Create zero-copy view with names attached atomically (no COW)
    result <- jlview(julia_named_array, names = names_vec)

    return(result)
}

#' Create a zero-copy R view of a named Julia matrix
#'
#' Creates a zero-copy ALTREP view of a Julia NamedArray matrix,
#' preserving row and column names as dimnames.
#'
#' @param julia_named_matrix A JuliaObject referencing a Julia NamedArray matrix
#' @return An ALTREP matrix with dimnames set from the Julia NamedArray
#' @export
#' @examples
#' if (interactive()) {
#'     JuliaCall::julia_setup()
#'     JuliaCall::julia_command("using NamedArrays")
#'     m <- JuliaCall::julia_eval('NamedArray(randn(3,2), (["a","b","c"], ["x","y"]))')
#'     x <- jlview_named_matrix(m)
#'     rownames(x) # returns c("a", "b", "c")
#'     colnames(x) # returns c("x", "y")
#' }
jlview_named_matrix <- function(julia_named_matrix) {
    jlview_ensure_init()

    # Get row and column names
    rownames <- JuliaCall::julia_call(
        "NamedArrays.names", julia_named_matrix, 1L,
        need_return = "R"
    )
    colnames <- JuliaCall::julia_call(
        "NamedArrays.names", julia_named_matrix, 2L,
        need_return = "R"
    )

    # Create zero-copy view with dimnames attached atomically (no COW)
    result <- jlview(julia_named_matrix, dimnames = list(rownames, colnames))

    return(result)
}
