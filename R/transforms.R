#' Compute log2(x + scalar) via Julia, returning a jlview
#'
#' For jlview inputs, the computation is performed entirely in Julia on the
#' pinned array, and the result is returned as a new jlview ALTREP object
#' (zero-copy). For non-jlview inputs, falls back to base R computation.
#'
#' @param x A jlview object or numeric vector/matrix
#' @param scalar Scalar to add before log2 (default 1e-5)
#' @return A jlview ALTREP object if input is jlview, otherwise a regular
#'   R numeric vector/matrix with the same dimensions.
#' @export
jlview_log2p <- function(x, scalar = 1e-5) {
    if (!is_jlview(x)) {
        return(log2(x + scalar))
    }

    jlview_ensure_init()

    # Extract pin_id from the jlview ALTREP object
    pin_id <- .Call("C_jlview_pin_id", x, PACKAGE = "jlview")
    if (is.na(pin_id)) {
        stop("jlview_log2p: cannot access released jlview object")
    }

    # Call Julia transform: looks up pinned array by id, computes
    # log2(x .+ scalar), returns the result as a new Julia array
    result_jl <- JuliaCall::julia_call(
        "JlviewSupport.transform_log2p",
        pin_id, scalar,
        need_return = "Julia"
    )

    # Wrap the Julia result array as a new jlview ALTREP object,
    # preserving names/dimnames from the input
    nms <- names(x)
    dnms <- dimnames(x)
    result <- jlview(result_jl, names = nms, dimnames = dnms)

    return(result)
}

#' Sweep a summary statistic from a matrix via Julia broadcast
#'
#' For jlview matrix inputs, the computation is performed entirely in Julia
#' using broadcast operations, and the result is returned as a new jlview
#' ALTREP object (zero-copy). For non-jlview inputs, falls back to base R
#' \code{\link[base]{sweep}}.
#'
#' @param x A jlview matrix or numeric matrix
#' @param MARGIN 1 for rows, 2 for columns
#' @param STATS A numeric vector of summary statistics (length must match
#'   the corresponding dimension of \code{x})
#' @param FUN One of \code{"/"}, \code{"*"}, \code{"-"}, \code{"+"}
#' @return A jlview ALTREP matrix if input is jlview, otherwise a regular
#'   R numeric matrix.
#' @export
jlview_sweep <- function(x, MARGIN, STATS, FUN = "/") {
    # Map function objects to strings
    if (is.function(FUN)) {
        fn_name <- deparse(substitute(FUN))
        if (!fn_name %in% c("/", "*", "-", "+")) {
            # Try matching the function identity
            if (identical(FUN, `/`)) fn_name <- "/"
            else if (identical(FUN, `*`)) fn_name <- "*"
            else if (identical(FUN, `-`)) fn_name <- "-"
            else if (identical(FUN, `+`)) fn_name <- "+"
            else stop("jlview_sweep: FUN must be one of '/', '*', '-', '+'")
        }
        FUN <- fn_name
    }

    stopifnot(MARGIN %in% c(1L, 2L))
    stopifnot(FUN %in% c("/", "*", "-", "+"))
    STATS <- as.numeric(STATS)

    if (!is_jlview(x)) {
        return(sweep(x, MARGIN, STATS, FUN))
    }

    # Validate dimensions
    d <- dim(x)
    if (is.null(d) || length(d) != 2L) {
        stop("jlview_sweep: x must be a matrix (2D)")
    }
    expected_len <- d[MARGIN]
    if (length(STATS) != expected_len) {
        stop(
            "jlview_sweep: length(STATS) = ", length(STATS),
            " but dim(x)[", MARGIN, "] = ", expected_len
        )
    }

    jlview_ensure_init()

    pin_id <- .Call("C_jlview_pin_id", x, PACKAGE = "jlview")
    if (is.na(pin_id)) {
        stop("jlview_sweep: cannot access released jlview object")
    }

    result_jl <- JuliaCall::julia_call(
        "JlviewSupport.transform_sweep",
        pin_id, STATS, as.integer(MARGIN), FUN,
        need_return = "Julia"
    )

    dnms <- dimnames(x)
    result <- jlview(result_jl, dimnames = dnms)

    return(result)
}

#' Transpose a matrix via Julia, returning a jlview
#'
#' For jlview matrix inputs, the transposition is performed entirely in Julia
#' on the pinned array, and the result is returned as a new jlview ALTREP
#' object. For non-jlview inputs, falls back to base R \code{\link[base]{t}}.
#'
#' @param x A jlview matrix or regular matrix
#' @return Transposed matrix as jlview ALTREP (or regular R matrix if not jlview)
#' @export
jlview_t <- function(x) {
    if (!is_jlview(x)) {
        return(t(x))
    }

    d <- dim(x)
    if (is.null(d) || length(d) != 2L) {
        stop("jlview_t: x must be a matrix (2D)")
    }

    jlview_ensure_init()

    pin_id <- .Call("C_jlview_pin_id", x, PACKAGE = "jlview")
    if (is.na(pin_id)) {
        stop("jlview_t: cannot access released jlview object")
    }

    result_jl <- JuliaCall::julia_call(
        "JlviewSupport.transform_transpose",
        pin_id,
        need_return = "Julia"
    )

    # Swap dimnames: rownames become colnames, colnames become rownames
    dn <- dimnames(x)
    new_dn <- if (!is.null(dn)) list(dn[[2]], dn[[1]]) else NULL

    result <- jlview(result_jl, dimnames = new_dn)

    return(result)
}

#' Compute column-wise maximums via Julia
#'
#' For jlview matrix inputs, the computation is performed entirely in Julia
#' on the pinned array. For non-jlview inputs, falls back to
#' \code{apply(x, 2, max)}.
#'
#' @param x A jlview matrix or numeric matrix
#' @return A named numeric vector of length \code{ncol(x)}.
#' @export
jlview_colMaxs <- function(x) {
    if (!is_jlview(x)) {
        result <- apply(x, 2, max)
        return(result)
    }

    d <- dim(x)
    if (is.null(d) || length(d) != 2L) {
        stop("jlview_colMaxs: x must be a matrix (2D)")
    }

    jlview_ensure_init()

    pin_id <- .Call("C_jlview_pin_id", x, PACKAGE = "jlview")
    if (is.na(pin_id)) {
        stop("jlview_colMaxs: cannot access released jlview object")
    }

    result <- JuliaCall::julia_call(
        "JlviewSupport.transform_colMaxs",
        pin_id,
        need_return = "R"
    )

    # Attach column names if present
    dn <- dimnames(x)
    if (!is.null(dn) && !is.null(dn[[2]])) {
        names(result) <- dn[[2]]
    }

    return(result)
}

#' Compute row-wise medians via Julia
#'
#' For jlview matrix inputs, the computation is performed entirely in Julia
#' on the pinned array. For non-jlview inputs, falls back to
#' \code{apply(x, 1, median)}.
#'
#' @param x A jlview matrix or numeric matrix
#' @return A named numeric vector of length \code{nrow(x)}.
#' @export
jlview_rowMedians <- function(x) {
    if (!is_jlview(x)) {
        result <- apply(x, 1, median)
        return(result)
    }

    d <- dim(x)
    if (is.null(d) || length(d) != 2L) {
        stop("jlview_rowMedians: x must be a matrix (2D)")
    }

    jlview_ensure_init()

    pin_id <- .Call("C_jlview_pin_id", x, PACKAGE = "jlview")
    if (is.na(pin_id)) {
        stop("jlview_rowMedians: cannot access released jlview object")
    }

    result <- JuliaCall::julia_call(
        "JlviewSupport.transform_rowMedians",
        pin_id,
        need_return = "R"
    )

    # Attach row names if present
    dn <- dimnames(x)
    if (!is.null(dn) && !is.null(dn[[1]])) {
        names(result) <- dn[[1]]
    }

    return(result)
}

#' Compute column-wise means via Julia
#'
#' For jlview matrix inputs, the computation is performed entirely in Julia
#' on the pinned array. For non-jlview inputs, falls back to
#' \code{\link[base]{colMeans}}.
#'
#' @param x A jlview matrix or numeric matrix
#' @return A named numeric vector of length \code{ncol(x)}.
#' @export
jlview_colMeans <- function(x) {
    if (!is_jlview(x)) {
        return(colMeans(x))
    }

    d <- dim(x)
    if (is.null(d) || length(d) != 2L) {
        stop("jlview_colMeans: x must be a matrix (2D)")
    }

    jlview_ensure_init()

    pin_id <- .Call("C_jlview_pin_id", x, PACKAGE = "jlview")
    if (is.na(pin_id)) {
        stop("jlview_colMeans: cannot access released jlview object")
    }

    result <- JuliaCall::julia_call(
        "JlviewSupport.transform_colMeans",
        pin_id,
        need_return = "R"
    )

    # Attach column names if present
    dn <- dimnames(x)
    if (!is.null(dn) && !is.null(dn[[2]])) {
        names(result) <- dn[[2]]
    }

    return(result)
}

#' Compute row-wise means via Julia
#'
#' For jlview matrix inputs, the computation is performed entirely in Julia
#' on the pinned array. For non-jlview inputs, falls back to
#' \code{\link[base]{rowMeans}}.
#'
#' @param x A jlview matrix or numeric matrix
#' @return A named numeric vector of length \code{nrow(x)}.
#' @export
jlview_rowMeans <- function(x) {
    if (!is_jlview(x)) {
        return(rowMeans(x))
    }

    d <- dim(x)
    if (is.null(d) || length(d) != 2L) {
        stop("jlview_rowMeans: x must be a matrix (2D)")
    }

    jlview_ensure_init()

    pin_id <- .Call("C_jlview_pin_id", x, PACKAGE = "jlview")
    if (is.na(pin_id)) {
        stop("jlview_rowMeans: cannot access released jlview object")
    }

    result <- JuliaCall::julia_call(
        "JlviewSupport.transform_rowMeans",
        pin_id,
        need_return = "R"
    )

    # Attach row names if present
    dn <- dimnames(x)
    if (!is.null(dn) && !is.null(dn[[1]])) {
        names(result) <- dn[[1]]
    }

    return(result)
}

#' Element-wise multiply matrix by vector via Julia
#'
#' A convenience wrapper around \code{\link{jlview_sweep}} using the \code{"*"}
#' operator. For jlview matrix inputs, the computation is performed entirely
#' in Julia. For non-jlview inputs, falls back to base R \code{\link[base]{sweep}}.
#'
#' @param x A jlview matrix or numeric matrix
#' @param vec A numeric vector (length must match the corresponding dimension)
#' @param margin 1 for rows, 2 for columns (default 2)
#' @return A jlview ALTREP matrix if input is jlview, otherwise a regular
#'   R numeric matrix.
#' @export
jlview_multiply <- function(x, vec, margin = 2) {
    jlview_sweep(x, margin, vec, "*")
}
