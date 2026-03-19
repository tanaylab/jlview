#' Create a zero-copy R sparse matrix view of a Julia SparseMatrixCSC
#'
#' Creates a \code{\link[Matrix]{dgCMatrix-class}} backed by a zero-copy ALTREP
#' vector for the nonzero values (\code{x} slot). The row indices (\code{i}
#' slot) and column pointers (\code{p} slot) are copied and shifted from
#' 1-based (Julia) to 0-based (R) indexing in Julia, then returned as plain
#' R integer vectors.
#'
#' @param julia_sparse_matrix A JuliaObject referencing a Julia
#'   \code{SparseMatrixCSC}. The value type must be supported for zero-copy
#'   (Float64, Float32, Int32, Int64, Int16, UInt8).
#' @param lazy_indices Ignored. Retained for API compatibility only. Previously
#'   controlled lazy vs eager materialization of ALTREP index vectors, which
#'   have been removed in favor of simple copy+shift in Julia.
#' @return A \code{\link[Matrix]{dgCMatrix-class}} sparse matrix.
#' @importClassesFrom Matrix dgCMatrix
#' @export
#' @examples
#' \dontrun{
#' JuliaCall::julia_setup()
#' JuliaCall::julia_command("using SparseArrays")
#' m <- JuliaCall::julia_eval("sprand(Float64, 100, 50, 0.1)")
#' s <- jlview_sparse(m)
#' class(s) # "dgCMatrix"
#' }
jlview_sparse <- function(julia_sparse_matrix, lazy_indices = FALSE) {
    jlview_ensure_init()

    if (!requireNamespace("Matrix", quietly = TRUE)) {
        stop(
            "jlview_sparse requires the 'Matrix' package. ",
            "Install it with install.packages(\"Matrix\")."
        )
    }

    support <- JuliaCall::julia_call(
        "JlviewSupport.check_support", julia_sparse_matrix,
        need_return = "R"
    )
    if (!support[[1]]) {
        warning(
            "jlview_sparse: value type ", support[[2]],
            " not supported for zero-copy, copying via JuliaCall"
        )
        return(JuliaCall::julia_call(
            "collect", julia_sparse_matrix,
            need_return = "R"
        ))
    }

    # -- nzval (nonzero values) — zero-copy ALTREP view as Float64
    nzval_jl <- JuliaCall::julia_call(
        "JlviewSupport.sparse_nzval_as_float64", julia_sparse_matrix,
        need_return = "Julia"
    )
    x <- jlview(nzval_jl)

    # -- rowval (row indices) — copy+shift in Julia (1-based to 0-based)
    i <- JuliaCall::julia_call(
        "JlviewSupport.copy_shift_index",
        JuliaCall::julia_call("SparseArrays.rowvals", julia_sparse_matrix, need_return = "Julia"),
        need_return = "R"
    )

    # -- colptr (column pointers) — copy+shift in Julia (1-based to 0-based)
    p <- JuliaCall::julia_call(
        "JlviewSupport.copy_shift_index",
        JuliaCall::julia_call("JlviewSupport._get_colptr", julia_sparse_matrix, need_return = "Julia"),
        need_return = "R"
    )

    nrow <- JuliaCall::julia_call("size", julia_sparse_matrix, 1L, need_return = "R")
    ncol <- JuliaCall::julia_call("size", julia_sparse_matrix, 2L, need_return = "R")

    methods::new(
        "dgCMatrix",
        i = as.integer(i),
        p = as.integer(p),
        x = x,
        Dim = as.integer(c(nrow, ncol))
    )
}
