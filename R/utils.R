#' Check if an object is a jlview ALTREP vector
#'
#' @param x An R object
#' @return `TRUE` if `x` is a jlview ALTREP vector, `FALSE` otherwise
#' @export
is_jlview <- function(x) {
    .Call("C_is_jlview", x, PACKAGE = "jlview")
}

#' Get information about a jlview object
#'
#' Returns metadata about a jlview ALTREP vector including the Julia
#' element type, length, writeability, and release status.
#'
#' @param x A jlview ALTREP vector
#' @return A named list with components:
#'   \describe{
#'     \item{type}{Julia element type (e.g., "Float64")}
#'     \item{length}{Number of elements}
#'     \item{writeable}{Whether the view allows direct writes}
#'     \item{released}{Whether the view has been released}
#'     \item{materialized}{Whether COW materialization has occurred}
#'   }
#' @export
jlview_info <- function(x) {
    .Call("C_jlview_info", x, PACKAGE = "jlview")
}
