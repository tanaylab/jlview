#' Create a zero-copy R sparse matrix view of a Julia SparseMatrixCSC
#'
#' Creates a \code{\link[Matrix]{dgCMatrix-class}} backed by zero-copy ALTREP
#' vectors for the nonzero values (\code{x} slot) and ALTREP index vectors for
#' the row indices (\code{i} slot) and column pointers (\code{p} slot).
#' The Julia-to-R index shift (1-based to 0-based) is handled lazily by the
#' ALTREP index class.
#'
#' @param julia_sparse_matrix A JuliaObject referencing a Julia
#'   \code{SparseMatrixCSC}. The value type must be supported for zero-copy
#'   (Float64, Float32, Int32, Int64, Int16, UInt8).
#' @param lazy_indices If \code{FALSE} (the default), the index vectors
#'   (\code{i} and \code{p}) are eagerly materialized into standard R integer
#'   vectors after construction. This avoids repeated lazy -1 shifts on every
#'   element access and is recommended for matrices that will be accessed
#'   many times. If \code{TRUE}, indices remain as lazy ALTREP views that
#'   compute the shift on-the-fly.
#' @return A \code{\link[Matrix]{dgCMatrix-class}} sparse matrix.
#' @importClassesFrom Matrix dgCMatrix
#' @export
#' @examples
#' \dontrun{
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

    # Verify the input is a SparseMatrixCSC with a supported value type
    support <- JuliaCall::julia_call(
        "JlviewSupport.check_support", julia_sparse_matrix,
        need_return = "R"
    )
    if (!support[[1]]) {
        stop(
            "jlview_sparse: value type ", support[[2]],
            " is not supported for zero-copy"
        )
    }

    # -- nzval (nonzero values) ------------------------------------------------
    # Get the nzval array as a JuliaObject and create a zero-copy ALTREP view.
    # jlview() handles pin + ALTREP creation atomically via C_jlview_create.
    nzval_jl <- JuliaCall::julia_call(
        "SparseArrays.nonzeros", julia_sparse_matrix,
        need_return = "Julia"
    )
    x <- jlview(nzval_jl)

    # -- rowval (row indices) --------------------------------------------------
    # Get as JuliaObject, pin on Julia side, then build ALTREP index in C.
    rowval_jl <- JuliaCall::julia_call(
        "SparseArrays.rowvals", julia_sparse_matrix,
        need_return = "Julia"
    )
    rowval_meta <- JuliaCall::julia_call(
        "JlviewSupport.pin_index", rowval_jl,
        need_return = "R"
    )
    rowval_extptr <- rowval_jl$id
    i <- .Call(
        "C_jlview_create_index",
        rowval_extptr,
        as.double(rowval_meta[[1]]), # pin_id
        as.integer(rowval_meta[[2]]), # length
        as.logical(rowval_meta[[3]]), # is_int64
        PACKAGE = "jlview"
    )

    # -- colptr (column pointers) ----------------------------------------------
    colptr_jl <- JuliaCall::julia_call(
        "JlviewSupport._get_colptr", julia_sparse_matrix,
        need_return = "Julia"
    )
    colptr_meta <- JuliaCall::julia_call(
        "JlviewSupport.pin_index", colptr_jl,
        need_return = "R"
    )
    colptr_extptr <- colptr_jl$id
    p <- .Call(
        "C_jlview_create_index",
        colptr_extptr,
        as.double(colptr_meta[[1]]), # pin_id
        as.integer(colptr_meta[[2]]), # length
        as.logical(colptr_meta[[3]]), # is_int64
        PACKAGE = "jlview"
    )

    # -- Dimensions ------------------------------------------------------------
    nrow <- JuliaCall::julia_call("size", julia_sparse_matrix, 1L,
        need_return = "R"
    )
    ncol <- JuliaCall::julia_call("size", julia_sparse_matrix, 2L,
        need_return = "R"
    )

    # -- Eagerly materialize indices if requested ------------------------------
    if (!lazy_indices) {
        .Call("C_jlview_index_materialize", i, PACKAGE = "jlview")
        .Call("C_jlview_index_materialize", p, PACKAGE = "jlview")
    }

    # -- Assemble dgCMatrix ----------------------------------------------------
    methods::new(
        "dgCMatrix",
        i = i,
        p = p,
        x = as.double(x),
        Dim = as.integer(c(nrow, ncol))
    )
}
