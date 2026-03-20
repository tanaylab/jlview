# ── jlview_top2_per_col tests ──

test_that("top2_per_col finds correct top-2 rows per column", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    # 4 rows (genes) x 3 columns (metacells)
    # Column 1: [4, 1, 3, 2] -> top1=row1(4), top2=row3(3)
    # Column 2: [5, 8, 7, 6] -> top1=row2(8), top2=row3(7)
    # Column 3: [12, 9, 10, 11] -> top1=row1(12), top2=row4(11)
    JuliaCall::julia_command("test_t2c_basic = Float64[4 5 12; 1 8 9; 3 7 10; 2 6 11]")
    jl_mat <- JuliaCall::julia_eval("test_t2c_basic", need_return = "Julia")
    x <- jlview(jl_mat)

    result <- jlview_top2_per_col(x)

    expect_equal(length(result$top1_idx), 3L)
    expect_equal(length(result$top2_idx), 3L)
    expect_equal(result$top1_idx, c(1L, 2L, 1L))
    expect_equal(result$top2_idx, c(3L, 3L, 4L))
    expect_equal(result$top1_val, c(4, 8, 12))
    expect_equal(result$top2_val, c(3, 7, 11))
})

test_that("top2_per_col on single-column matrix", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_t2c_1col = reshape(Float64[3, 1, 4, 1, 5], 5, 1)")
    jl_mat <- JuliaCall::julia_eval("test_t2c_1col", need_return = "Julia")
    x <- jlview(jl_mat)

    result <- jlview_top2_per_col(x)

    expect_equal(length(result$top1_idx), 1L)
    expect_equal(result$top1_idx, 5L)  # value 5
    expect_equal(result$top2_idx, 3L)  # value 4
    expect_equal(result$top1_val, 5.0)
    expect_equal(result$top2_val, 4.0)
})

test_that("top2_per_col on two-row matrix", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    # 2 rows x 3 columns: top1 and top2 are the only rows
    JuliaCall::julia_command("test_t2c_2row = Float64[1 5 3; 4 2 6]")
    jl_mat <- JuliaCall::julia_eval("test_t2c_2row", need_return = "Julia")
    x <- jlview(jl_mat)

    result <- jlview_top2_per_col(x)

    expect_equal(result$top1_idx, c(2L, 1L, 2L))
    expect_equal(result$top2_idx, c(1L, 2L, 1L))
    expect_equal(result$top1_val, c(4, 5, 6))
    expect_equal(result$top2_val, c(1, 2, 3))
})

test_that("top2_per_col on large matrix (3000x500)", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_t2c_large = rand(3000, 500)")
    jl_mat <- JuliaCall::julia_eval("test_t2c_large", need_return = "Julia")
    x <- jlview(jl_mat)

    result <- jlview_top2_per_col(x)

    # Compare against R reference
    mat <- as.matrix(x)
    for (j in seq_len(ncol(mat))) {
        col <- mat[, j]
        r_top1 <- which.max(col)
        col[r_top1] <- -Inf
        r_top2 <- which.max(col)
        expect_equal(result$top1_idx[j], as.integer(r_top1))
        expect_equal(result$top2_idx[j], as.integer(r_top2))
    }
})

test_that("top2_per_col non-jlview fallback", {
    mat <- matrix(c(4, 1, 3, 2, 5, 8, 7, 6, 12, 9, 10, 11), nrow = 4, ncol = 3)

    result <- jlview_top2_per_col(mat)

    expect_equal(result$top1_idx, c(1L, 2L, 1L))
    expect_equal(result$top2_idx, c(3L, 3L, 4L))
    expect_equal(result$top1_val, c(4, 8, 12))
    expect_equal(result$top2_val, c(3, 7, 11))
})

test_that("top2_per_col rejects non-matrix", {
    expect_error(jlview_top2_per_col(1:10), "must be a matrix")
})

# ── jlview_top2_per_row tests ──

test_that("top2_per_row finds correct top-2 columns per row", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    # 3 rows (metacells) x 4 columns (genes)
    # Row 1: [4, 5, 12, 2] -> top1=col3(12), top2=col2(5)
    # Row 2: [1, 8, 9, 6]  -> top1=col3(9), top2=col2(8)
    # Row 3: [3, 7, 10, 11] -> top1=col4(11), top2=col3(10)
    JuliaCall::julia_command("test_t2r_basic = Float64[4 5 12 2; 1 8 9 6; 3 7 10 11]")
    jl_mat <- JuliaCall::julia_eval("test_t2r_basic", need_return = "Julia")
    x <- jlview(jl_mat)

    result <- jlview_top2_per_row(x)

    expect_equal(length(result$top1_idx), 3L)
    expect_equal(length(result$top2_idx), 3L)
    expect_equal(result$top1_idx, c(3L, 3L, 4L))
    expect_equal(result$top2_idx, c(2L, 2L, 3L))
    expect_equal(result$top1_val, c(12, 9, 11))
    expect_equal(result$top2_val, c(5, 8, 10))
})

test_that("top2_per_row on single-row matrix", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_t2r_1row = reshape(Float64[3, 1, 4, 1, 5], 1, 5)")
    jl_mat <- JuliaCall::julia_eval("test_t2r_1row", need_return = "Julia")
    x <- jlview(jl_mat)

    result <- jlview_top2_per_row(x)

    expect_equal(length(result$top1_idx), 1L)
    expect_equal(result$top1_idx, 5L)  # value 5
    expect_equal(result$top2_idx, 3L)  # value 4
    expect_equal(result$top1_val, 5.0)
    expect_equal(result$top2_val, 4.0)
})

test_that("top2_per_row on large matrix (500x3000)", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_t2r_large = rand(500, 3000)")
    jl_mat <- JuliaCall::julia_eval("test_t2r_large", need_return = "Julia")
    x <- jlview(jl_mat)

    result <- jlview_top2_per_row(x)

    # Compare against R reference using max.col
    mat <- as.matrix(x)
    top1_idx_r <- max.col(mat, ties.method = "first")
    top1_val_r <- mat[cbind(seq_len(nrow(mat)), top1_idx_r)]
    mat[cbind(seq_len(nrow(mat)), top1_idx_r)] <- -Inf
    top2_idx_r <- max.col(mat, ties.method = "first")

    expect_equal(result$top1_idx, as.integer(top1_idx_r))
    expect_equal(result$top2_idx, as.integer(top2_idx_r))
    expect_equal(result$top1_val, top1_val_r, tolerance = 1e-10)
})

test_that("top2_per_row non-jlview fallback", {
    mat <- matrix(c(4, 1, 3, 5, 8, 7, 12, 9, 10, 2, 6, 11), nrow = 3, ncol = 4)

    result <- jlview_top2_per_row(mat)

    expect_equal(result$top1_idx, c(3L, 3L, 4L))
    expect_equal(result$top2_idx, c(2L, 2L, 3L))
    expect_equal(result$top1_val, c(12, 9, 11))
    expect_equal(result$top2_val, c(5, 8, 10))
})

test_that("top2_per_row rejects non-matrix", {
    expect_error(jlview_top2_per_row(1:10), "must be a matrix")
})

test_that("top2_per_row does not mutate input", {
    mat <- matrix(c(4, 1, 3, 5, 8, 7, 12, 9, 10), nrow = 3, ncol = 3)
    mat_copy <- mat
    jlview_top2_per_row(mat)
    expect_identical(mat, mat_copy)
})

test_that("top2_per_col does not mutate input", {
    mat <- matrix(c(4, 1, 3, 5, 8, 7, 12, 9, 10), nrow = 3, ncol = 3)
    mat_copy <- mat
    jlview_top2_per_col(mat)
    expect_identical(mat, mat_copy)
})
