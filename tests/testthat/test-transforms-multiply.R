# ── jlview_multiply tests ──

test_that("multiply columns (margin=2) matches sweep(mat, 2, vec, '*')", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_mul_col = reshape(collect(1.0:12.0), 3, 4)")
    jl_mat <- JuliaCall::julia_eval("test_mul_col", need_return = "Julia")
    x <- jlview(jl_mat)

    vec <- c(2.0, 3.0, 4.0, 5.0)
    result <- jlview_multiply(x, vec, margin = 2)
    expected <- sweep(matrix(1:12, nrow = 3, ncol = 4), 2, vec, "*")

    expect_true(is_jlview(result))
    expect_equal(dim(result), c(3L, 4L))
    expect_true(max(abs(as.numeric(result) - as.numeric(expected))) < 1e-10)
})

test_that("multiply rows (margin=1) matches sweep(mat, 1, vec, '*')", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_mul_row = reshape(collect(1.0:12.0), 3, 4)")
    jl_mat <- JuliaCall::julia_eval("test_mul_row", need_return = "Julia")
    x <- jlview(jl_mat)

    vec <- c(10.0, 20.0, 30.0)
    result <- jlview_multiply(x, vec, margin = 1)
    expected <- sweep(matrix(1:12, nrow = 3, ncol = 4), 1, vec, "*")

    expect_true(is_jlview(result))
    expect_equal(dim(result), c(3L, 4L))
    expect_true(max(abs(as.numeric(result) - as.numeric(expected))) < 1e-10)
})

test_that("multiply preserves dimnames", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_mul_dn = reshape(collect(1.0:6.0), 2, 3)")
    jl_mat <- JuliaCall::julia_eval("test_mul_dn", need_return = "Julia")
    x <- jlview(jl_mat, dimnames = list(c("r1", "r2"), c("c1", "c2", "c3")))

    result <- jlview_multiply(x, c(2.0, 3.0, 4.0), margin = 2)

    expect_equal(rownames(result), c("r1", "r2"))
    expect_equal(colnames(result), c("c1", "c2", "c3"))
})

test_that("multiply result is jlview ALTREP", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_mul_altrep = reshape(collect(1.0:12.0), 3, 4)")
    jl_mat <- JuliaCall::julia_eval("test_mul_altrep", need_return = "Julia")
    x <- jlview(jl_mat)

    result <- jlview_multiply(x, c(1.0, 1.0, 1.0, 1.0), margin = 2)

    expect_true(is_jlview(result))
    info <- jlview_info(result)
    expect_equal(info$type, "Float64")
    expect_false(info$materialized)
})

test_that("multiply non-jlview fallback", {
    mat <- matrix(1:12, nrow = 3, ncol = 4)
    vec <- c(2.0, 3.0, 4.0, 5.0)

    result <- jlview_multiply(mat, vec, margin = 2)
    expected <- sweep(mat, 2, vec, "*")

    expect_false(is_jlview(result))
    expect_equal(result, expected)
    expect_equal(dim(result), c(3L, 4L))
})

test_that("multiply default margin is 2 (columns)", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_mul_def = reshape(collect(1.0:12.0), 3, 4)")
    jl_mat <- JuliaCall::julia_eval("test_mul_def", need_return = "Julia")
    x <- jlview(jl_mat)

    vec <- c(2.0, 3.0, 4.0, 5.0)
    result_default <- jlview_multiply(x, vec)
    result_explicit <- jlview_multiply(x, vec, margin = 2)

    expect_true(max(abs(as.numeric(result_default) - as.numeric(result_explicit))) < 1e-10)
})

test_that("multiply large matrix (3000x500)", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_mul_large = rand(3000, 500)")
    jl_mat <- JuliaCall::julia_eval("test_mul_large", need_return = "Julia")
    x <- jlview(jl_mat)

    vec <- runif(500)
    result <- jlview_multiply(x, vec, margin = 2)
    expected <- sweep(as.matrix(x), 2, vec, "*")

    expect_true(is_jlview(result))
    expect_equal(dim(result), c(3000L, 500L))
    expect_true(max(abs(as.numeric(result) - as.numeric(expected))) < 1e-10)
})

test_that("multiply by ones is identity", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_mul_id = reshape(collect(1.0:12.0), 3, 4)")
    jl_mat <- JuliaCall::julia_eval("test_mul_id", need_return = "Julia")
    x <- jlview(jl_mat)

    result <- jlview_multiply(x, rep(1.0, 4), margin = 2)
    expected <- as.numeric(x)

    expect_true(max(abs(as.numeric(result) - expected)) < 1e-10)
})

test_that("multiply by zeros gives zeros", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_mul_zero = reshape(collect(1.0:12.0), 3, 4)")
    jl_mat <- JuliaCall::julia_eval("test_mul_zero", need_return = "Julia")
    x <- jlview(jl_mat)

    result <- jlview_multiply(x, rep(0.0, 4), margin = 2)

    expect_true(all(as.numeric(result) == 0))
})
