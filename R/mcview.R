# MCView-specific transform functions
#
# These functions implement domain-specific bioinformatics operations
# used by the MCView metacell viewer. They are separated from the
# general-purpose transforms in transforms.R to keep the core jlview
# namespace clean.

#' Compute fold-change (x / rowMedians(x))
#'
#' Computes fold-change by dividing each row by its median across columns.
#' This is a common bioinformatics normalization step (EGC to fold-change/footprint).
#'
#' For jlview inputs, the entire computation (optional epsilon addition, row medians,
#' and division) is performed in Julia on the pinned array, returning a new jlview
#' ALTREP object without materializing the input. For non-jlview inputs, falls back
#' to \code{matrixStats::rowMedians} in R.
#'
#' @param x A jlview matrix or regular matrix
#' @param epsilon Scalar to add to each element before computing fold-change.
#'   Default 0 (no addition). When non-zero, fuses the \code{x + epsilon} and
#'   \code{x / rowMedians(x)} steps into a single Julia call, avoiding an
#'   intermediate R materialization.
#' @return Fold-change matrix (same dimensions as input). If input is jlview,
#'   the result is also a jlview ALTREP object (zero-copy from Julia).
#' @export
jlview_fp <- function(x, epsilon = 0) {
    if (!is_jlview(x)) {
        if (!requireNamespace("matrixStats", quietly = TRUE)) {
            stop("jlview_fp requires the matrixStats package for non-jlview inputs")
        }
        if (epsilon != 0) {
            x <- x + epsilon
        }
        dn <- dimnames(x)
        meds <- matrixStats::rowMedians(as.matrix(x), na.rm = TRUE)
        result <- x / meds
        if (!is.null(dn) && is.null(dimnames(result))) {
            dimnames(result) <- dn
        }
        return(result)
    }

    # jlview path: do the entire computation in Julia (epsilon + medians + divide)
    jlview_ensure_init()

    pin_id <- .Call("C_jlview_pin_id", x, PACKAGE = "jlview")
    if (is.na(pin_id)) {
        stop("jlview_fp: cannot access released jlview object")
    }

    result_jl <- JuliaCall::julia_call(
        "JlviewSupport.transform_fp",
        pin_id, as.numeric(epsilon),
        need_return = "Julia"
    )

    dn <- dimnames(x)
    jlview(result_jl, dimnames = dn)
}

#' Find top-2 row indices and values per column
#'
#' For a gene x metacell matrix, this returns the top-2 genes (rows) per
#' metacell (column), without mutating the input matrix.
#'
#' For jlview inputs, the computation is performed entirely in Julia on the
#' pinned array. For non-jlview inputs, falls back to R computation using
#' \code{\link[base]{max.col}}.
#'
#' @param x A jlview matrix or numeric matrix (2D)
#' @return A list with four components, each of length \code{ncol(x)}:
#'   \describe{
#'     \item{top1_idx}{Integer vector of row indices of the largest value per column (1-indexed)}
#'     \item{top2_idx}{Integer vector of row indices of the second largest value per column (1-indexed)}
#'     \item{top1_val}{Numeric vector of the largest value per column}
#'     \item{top2_val}{Numeric vector of the second largest value per column}
#'   }
#' @export
jlview_top2_per_col <- function(x) {
    d <- dim(x)
    if (is.null(d) || length(d) != 2L) {
        stop("jlview_top2_per_col: x must be a matrix (2D)")
    }

    if (!is_jlview(x)) {
        # R fallback: transpose to use max.col (which finds max per row)
        xt <- t(x)
        top1_idx <- max.col(xt, ties.method = "first")
        top1_val <- xt[cbind(seq_len(nrow(xt)), top1_idx)]
        # Mask top1 to find top2
        xt[cbind(seq_len(nrow(xt)), top1_idx)] <- -Inf
        top2_idx <- max.col(xt, ties.method = "first")
        top2_val <- xt[cbind(seq_len(nrow(xt)), top2_idx)]
        return(list(
            top1_idx = as.integer(top1_idx),
            top2_idx = as.integer(top2_idx),
            top1_val = as.numeric(top1_val),
            top2_val = as.numeric(top2_val)
        ))
    }

    jlview_ensure_init()

    pin_id <- .Call("C_jlview_pin_id", x, PACKAGE = "jlview")
    if (is.na(pin_id)) {
        stop("jlview_top2_per_col: cannot access released jlview object")
    }

    result <- JuliaCall::julia_call(
        "JlviewSupport.transform_top2_per_col",
        pin_id,
        need_return = "R"
    )

    list(
        top1_idx = as.integer(result[[1]]),
        top2_idx = as.integer(result[[2]]),
        top1_val = as.numeric(result[[3]]),
        top2_val = as.numeric(result[[4]])
    )
}

#' Find top-2 column indices and values per row
#'
#' For a metacell x gene matrix, this returns the top-2 genes (columns) per
#' metacell (row), without mutating the input matrix.
#'
#' For jlview inputs, the computation is performed entirely in Julia on the
#' pinned array. For non-jlview inputs, falls back to R computation using
#' \code{\link[base]{max.col}}.
#'
#' @param x A jlview matrix or numeric matrix (2D)
#' @return A list with four components, each of length \code{nrow(x)}:
#'   \describe{
#'     \item{top1_idx}{Integer vector of column indices of the largest value per row (1-indexed)}
#'     \item{top2_idx}{Integer vector of column indices of the second largest value per row (1-indexed)}
#'     \item{top1_val}{Numeric vector of the largest value per row}
#'     \item{top2_val}{Numeric vector of the second largest value per row}
#'   }
#' @export
jlview_top2_per_row <- function(x) {
    d <- dim(x)
    if (is.null(d) || length(d) != 2L) {
        stop("jlview_top2_per_row: x must be a matrix (2D)")
    }

    if (!is_jlview(x)) {
        # R fallback using max.col
        top1_idx <- max.col(x, ties.method = "first")
        top1_val <- x[cbind(seq_len(nrow(x)), top1_idx)]
        # Mask top1 to find top2 (copy to avoid mutating input)
        xc <- x
        xc[cbind(seq_len(nrow(xc)), top1_idx)] <- -Inf
        top2_idx <- max.col(xc, ties.method = "first")
        top2_val <- x[cbind(seq_len(nrow(x)), top2_idx)]
        return(list(
            top1_idx = as.integer(top1_idx),
            top2_idx = as.integer(top2_idx),
            top1_val = as.numeric(top1_val),
            top2_val = as.numeric(top2_val)
        ))
    }

    jlview_ensure_init()

    pin_id <- .Call("C_jlview_pin_id", x, PACKAGE = "jlview")
    if (is.na(pin_id)) {
        stop("jlview_top2_per_row: cannot access released jlview object")
    }

    result <- JuliaCall::julia_call(
        "JlviewSupport.transform_top2_per_row",
        pin_id,
        need_return = "R"
    )

    list(
        top1_idx = as.integer(result[[1]]),
        top2_idx = as.integer(result[[2]]),
        top1_val = as.numeric(result[[3]]),
        top2_val = as.numeric(result[[4]])
    )
}
