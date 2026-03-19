# ── jlview_sweep tests ──

test_that("sweep divide columns (margin=2) matches R sweep", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_sw_divcol = reshape(collect(1.0:12.0), 3, 4)")
    jl_mat <- JuliaCall::julia_eval("test_sw_divcol", need_return = "Julia")
    x <- jlview(jl_mat)

    stats <- c(2.0, 3.0, 4.0, 5.0)
    result <- jlview_sweep(x, 2, stats, "/")
    expected <- sweep(matrix(1:12, nrow = 3, ncol = 4), 2, stats, "/")

    expect_true(is_jlview(result))
    expect_equal(dim(result), c(3L, 4L))
    expect_true(max(abs(as.numeric(result) - as.numeric(expected))) < 1e-10)
})

test_that("sweep divide rows (margin=1) matches R sweep", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_sw_divrow = reshape(collect(1.0:12.0), 3, 4)")
    jl_mat <- JuliaCall::julia_eval("test_sw_divrow", need_return = "Julia")
    x <- jlview(jl_mat)

    stats <- c(2.0, 3.0, 4.0)
    result <- jlview_sweep(x, 1, stats, "/")
    expected <- sweep(matrix(1:12, nrow = 3, ncol = 4), 1, stats, "/")

    expect_true(is_jlview(result))
    expect_equal(dim(result), c(3L, 4L))
    expect_true(max(abs(as.numeric(result) - as.numeric(expected))) < 1e-10)
})

test_that("sweep multiply columns matches R sweep", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_sw_mulcol = reshape(collect(1.0:12.0), 3, 4)")
    jl_mat <- JuliaCall::julia_eval("test_sw_mulcol", need_return = "Julia")
    x <- jlview(jl_mat)

    stats <- c(10.0, 20.0, 30.0, 40.0)
    result <- jlview_sweep(x, 2, stats, "*")
    expected <- sweep(matrix(1:12, nrow = 3, ncol = 4), 2, stats, "*")

    expect_true(is_jlview(result))
    expect_true(max(abs(as.numeric(result) - as.numeric(expected))) < 1e-10)
})

test_that("sweep subtract rows matches R sweep", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_sw_subrow = reshape(collect(1.0:12.0), 3, 4)")
    jl_mat <- JuliaCall::julia_eval("test_sw_subrow", need_return = "Julia")
    x <- jlview(jl_mat)

    stats <- c(0.5, 1.5, 2.5)
    result <- jlview_sweep(x, 1, stats, "-")
    expected <- sweep(matrix(1:12, nrow = 3, ncol = 4), 1, stats, "-")

    expect_true(is_jlview(result))
    expect_true(max(abs(as.numeric(result) - as.numeric(expected))) < 1e-10)
})

test_that("sweep add columns matches R sweep", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_sw_addcol = reshape(collect(1.0:12.0), 3, 4)")
    jl_mat <- JuliaCall::julia_eval("test_sw_addcol", need_return = "Julia")
    x <- jlview(jl_mat)

    stats <- c(100.0, 200.0, 300.0, 400.0)
    result <- jlview_sweep(x, 2, stats, "+")
    expected <- sweep(matrix(1:12, nrow = 3, ncol = 4), 2, stats, "+")

    expect_true(is_jlview(result))
    expect_true(max(abs(as.numeric(result) - as.numeric(expected))) < 1e-10)
})

test_that("sweep preserves dimnames", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_sw_dn = reshape(collect(1.0:6.0), 2, 3)")
    jl_mat <- JuliaCall::julia_eval("test_sw_dn", need_return = "Julia")
    x <- jlview(jl_mat, dimnames = list(c("r1", "r2"), c("c1", "c2", "c3")))

    stats <- c(1.0, 2.0, 3.0)
    result <- jlview_sweep(x, 2, stats, "/")

    expect_equal(rownames(result), c("r1", "r2"))
    expect_equal(colnames(result), c("c1", "c2", "c3"))
})

test_that("sweep result is jlview ALTREP", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_sw_altrep = reshape(collect(1.0:12.0), 3, 4)")
    jl_mat <- JuliaCall::julia_eval("test_sw_altrep", need_return = "Julia")
    x <- jlview(jl_mat)

    result <- jlview_sweep(x, 2, c(1.0, 1.0, 1.0, 1.0), "/")

    expect_true(is_jlview(result))
    info <- jlview_info(result)
    expect_equal(info$type, "Float64")
    expect_false(info$materialized)
})

test_that("sweep numeric accuracy", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    vals <- c(0.001, 0.01, 0.1, 1.0, 10.0, 100.0, 1000.0, 10000.0)
    JuliaCall::julia_command(
        paste0("test_sw_acc = reshape([", paste(vals, collapse = ", "), "], 2, 4)")
    )
    jl_mat <- JuliaCall::julia_eval("test_sw_acc", need_return = "Julia")
    x <- jlview(jl_mat)

    stats <- c(3.14, 2.71, 1.41, 1.73)
    result <- jlview_sweep(x, 2, stats, "/")
    expected <- sweep(matrix(vals, nrow = 2, ncol = 4), 2, stats, "/")

    expect_true(max(abs(as.numeric(result) - as.numeric(expected))) < 1e-10)
})

test_that("sweep single-row matrix", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_sw_1row = reshape(collect(1.0:5.0), 1, 5)")
    jl_mat <- JuliaCall::julia_eval("test_sw_1row", need_return = "Julia")
    x <- jlview(jl_mat)

    stats <- c(2.0, 3.0, 4.0, 5.0, 6.0)
    result <- jlview_sweep(x, 2, stats, "/")
    expected <- sweep(matrix(1:5, nrow = 1, ncol = 5), 2, stats, "/")

    expect_true(is_jlview(result))
    expect_equal(dim(result), c(1L, 5L))
    expect_true(max(abs(as.numeric(result) - as.numeric(expected))) < 1e-10)
})

test_that("sweep single-column matrix", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_sw_1col = reshape(collect(1.0:5.0), 5, 1)")
    jl_mat <- JuliaCall::julia_eval("test_sw_1col", need_return = "Julia")
    x <- jlview(jl_mat)

    stats <- c(2.0, 3.0, 4.0, 5.0, 6.0)
    result <- jlview_sweep(x, 1, stats, "/")
    expected <- sweep(matrix(1:5, nrow = 5, ncol = 1), 1, stats, "/")

    expect_true(is_jlview(result))
    expect_equal(dim(result), c(5L, 1L))
    expect_true(max(abs(as.numeric(result) - as.numeric(expected))) < 1e-10)
})

test_that("sweep large matrix correctness", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_sw_large = rand(5000, 1000)")
    jl_mat <- JuliaCall::julia_eval("test_sw_large", need_return = "Julia")
    x <- jlview(jl_mat)

    # Use colSums as stats for column sweep
    col_sums <- colSums(x)
    result <- jlview_sweep(x, 2, col_sums, "/")
    expected <- sweep(as.matrix(x), 2, col_sums, "/")

    expect_true(is_jlview(result))
    expect_equal(dim(result), c(5000L, 1000L))
    expect_true(max(abs(as.numeric(result) - as.numeric(expected))) < 1e-10)
})

test_that("sweep non-jlview fallback", {
    mat <- matrix(1:12, nrow = 3, ncol = 4)
    stats <- c(2.0, 3.0, 4.0, 5.0)

    result <- jlview_sweep(mat, 2, stats, "/")
    expected <- sweep(mat, 2, stats, "/")

    expect_false(is_jlview(result))
    expect_equal(result, expected)
    expect_equal(dim(result), c(3L, 4L))
})

test_that("sweep error on wrong-length STATS", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_sw_badlen = reshape(collect(1.0:12.0), 3, 4)")
    jl_mat <- JuliaCall::julia_eval("test_sw_badlen", need_return = "Julia")
    x <- jlview(jl_mat)

    # margin=2 expects 4 stats but we give 3
    expect_error(jlview_sweep(x, 2, c(1.0, 2.0, 3.0), "/"), "length\\(STATS\\)")
    # margin=1 expects 3 stats but we give 4
    expect_error(jlview_sweep(x, 1, c(1.0, 2.0, 3.0, 4.0), "/"), "length\\(STATS\\)")
})

test_that("sweep error on invalid FUN", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_sw_badfun = reshape(collect(1.0:12.0), 3, 4)")
    jl_mat <- JuliaCall::julia_eval("test_sw_badfun", need_return = "Julia")
    x <- jlview(jl_mat)

    expect_error(jlview_sweep(x, 2, c(1.0, 2.0, 3.0, 4.0), "^"))
})
