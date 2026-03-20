# ── jlview_fp tests ──

test_that("fp matches R egc_to_fp: x / rowMedians(x)", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    # 4 rows x 6 columns
    JuliaCall::julia_command("test_fp_basic = reshape(collect(1.0:24.0), 4, 6)")
    jl_mat <- JuliaCall::julia_eval("test_fp_basic", need_return = "Julia")
    x <- jlview(jl_mat)

    result <- jlview_fp(x)
    mat <- matrix(1:24, nrow = 4, ncol = 6)
    expected <- mat / matrixStats::rowMedians(mat)

    expect_equal(dim(result), dim(expected))
    expect_true(max(abs(as.matrix(result) - expected)) < 1e-10)
})

test_that("fp preserves dimnames", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_fp_named = reshape(collect(1.0:6.0), 2, 3)")
    jl_mat <- JuliaCall::julia_eval("test_fp_named", need_return = "Julia")
    x <- jlview(jl_mat, dimnames = list(c("gene1", "gene2"), c("mc1", "mc2", "mc3")))

    result <- jlview_fp(x)

    expect_equal(rownames(result), c("gene1", "gene2"))
    expect_equal(colnames(result), c("mc1", "mc2", "mc3"))
})

test_that("fp result is a matrix with correct dimensions", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_fp_jlv = reshape(collect(1.0:12.0), 3, 4)")
    jl_mat <- JuliaCall::julia_eval("test_fp_jlv", need_return = "Julia")
    x <- jlview(jl_mat)

    result <- jlview_fp(x)
    expect_true(is.matrix(result))
    expect_equal(dim(result), c(3L, 4L))
})

test_that("fp numeric accuracy within 1e-10", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    # Use random data for thorough accuracy check
    JuliaCall::julia_command("test_fp_acc = rand(50, 100) .+ 0.01")
    jl_mat <- JuliaCall::julia_eval("test_fp_acc", need_return = "Julia")
    x <- jlview(jl_mat)

    result <- as.matrix(jlview_fp(x))
    mat <- as.matrix(x)
    expected <- mat / matrixStats::rowMedians(mat)

    expect_true(max(abs(result - expected)) < 1e-10)
})

test_that("fp on single-row matrix", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_fp_1row = reshape(collect(1.0:5.0), 1, 5)")
    jl_mat <- JuliaCall::julia_eval("test_fp_1row", need_return = "Julia")
    x <- jlview(jl_mat)

    result <- jlview_fp(x)
    mat <- matrix(1:5, nrow = 1)
    expected <- mat / median(1:5)

    expect_equal(dim(result), c(1L, 5L))
    expect_true(max(abs(as.matrix(result) - expected)) < 1e-10)
})

test_that("fp on large matrix (5000x1000)", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_fp_large = rand(5000, 1000) .+ 0.001")
    jl_mat <- JuliaCall::julia_eval("test_fp_large", need_return = "Julia")
    x <- jlview(jl_mat)

    result <- as.matrix(jlview_fp(x))
    mat <- as.matrix(x)
    expected <- mat / matrixStats::rowMedians(mat)

    expect_equal(dim(result), c(5000L, 1000L))
    expect_true(max(abs(result - expected)) < 1e-10)
})

test_that("fp non-jlview fallback", {
    mat <- matrix(c(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12), nrow = 3, ncol = 4)

    result <- jlview_fp(mat)
    expected <- mat / matrixStats::rowMedians(mat)

    expect_false(is_jlview(result))
    expect_true(max(abs(result - expected)) < 1e-10)
})

test_that("fp with epsilon fuses addition and division (jlview path)", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_fp_eps = reshape(collect(0.0:11.0), 3, 4)")
    jl_mat <- JuliaCall::julia_eval("test_fp_eps", need_return = "Julia")
    x <- jlview(jl_mat)

    eps <- 1e-5
    result <- jlview_fp(x, epsilon = eps)

    # Expected: (x + eps) / rowMedians(x + eps)
    mat <- as.matrix(x) + eps
    expected <- mat / matrixStats::rowMedians(mat)

    expect_true(is_jlview(result))
    expect_equal(dim(result), c(3L, 4L))
    expect_true(max(abs(as.matrix(result) - expected)) < 1e-10)
})

test_that("fp with epsilon=0 is identical to no epsilon (jlview path)", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_fp_noeps = reshape(collect(1.0:12.0), 3, 4)")
    jl_mat <- JuliaCall::julia_eval("test_fp_noeps", need_return = "Julia")
    x <- jlview(jl_mat)

    result0 <- as.matrix(jlview_fp(x, epsilon = 0))
    result_default <- as.matrix(jlview_fp(x))

    expect_true(max(abs(result0 - result_default)) < 1e-15)
})

test_that("fp with epsilon non-jlview fallback", {
    mat <- matrix(c(0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8), nrow = 3, ncol = 3)

    eps <- 1e-5
    result <- jlview_fp(mat, epsilon = eps)
    mat_eps <- mat + eps
    expected <- mat_eps / matrixStats::rowMedians(mat_eps)

    expect_false(is_jlview(result))
    expect_true(max(abs(result - expected)) < 1e-10)
})
