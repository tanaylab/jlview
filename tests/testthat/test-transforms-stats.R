# ── jlview_colMaxs tests ──

test_that("colMaxs matches apply(mat, 2, max)", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_cm_basic = reshape(collect(1.0:12.0), 3, 4)")
    jl_mat <- JuliaCall::julia_eval("test_cm_basic", need_return = "Julia")
    x <- jlview(jl_mat)

    result <- jlview_colMaxs(x)
    expected <- apply(matrix(1:12, nrow = 3, ncol = 4), 2, max)

    expect_equal(length(result), 4L)
    expect_true(max(abs(result - expected)) < 1e-10)
})

test_that("colMaxs returns named vector from colnames", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_cm_named = reshape(collect(1.0:6.0), 2, 3)")
    jl_mat <- JuliaCall::julia_eval("test_cm_named", need_return = "Julia")
    x <- jlview(jl_mat, dimnames = list(c("r1", "r2"), c("a", "b", "c")))

    result <- jlview_colMaxs(x)

    expect_equal(names(result), c("a", "b", "c"))
    expect_equal(unname(result), c(2, 4, 6))
})

test_that("colMaxs on integer matrix", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_cm_int = Int32.(reshape(collect(1:12), 3, 4))")
    jl_mat <- JuliaCall::julia_eval("test_cm_int", need_return = "Julia")
    x <- jlview(jl_mat)

    result <- jlview_colMaxs(x)
    expected <- apply(matrix(1:12, nrow = 3, ncol = 4), 2, max)

    expect_equal(length(result), 4L)
    expect_true(max(abs(result - expected)) < 1e-10)
})

test_that("colMaxs on single-row matrix", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_cm_1row = reshape(collect(1.0:5.0), 1, 5)")
    jl_mat <- JuliaCall::julia_eval("test_cm_1row", need_return = "Julia")
    x <- jlview(jl_mat)

    result <- jlview_colMaxs(x)
    expected <- 1:5

    expect_equal(length(result), 5L)
    expect_true(max(abs(result - expected)) < 1e-10)
})

test_that("colMaxs on single-column matrix", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_cm_1col = reshape(collect(1.0:5.0), 5, 1)")
    jl_mat <- JuliaCall::julia_eval("test_cm_1col", need_return = "Julia")
    x <- jlview(jl_mat)

    result <- jlview_colMaxs(x)

    expect_equal(length(result), 1L)
    expect_equal(result[1], 5.0)
})

test_that("colMaxs on large matrix (3000x500)", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_cm_large = rand(3000, 500)")
    jl_mat <- JuliaCall::julia_eval("test_cm_large", need_return = "Julia")
    x <- jlview(jl_mat)

    result <- jlview_colMaxs(x)
    expected <- apply(as.matrix(x), 2, max)

    expect_equal(length(result), 500L)
    expect_true(max(abs(result - expected)) < 1e-10)
})

test_that("colMaxs non-jlview fallback", {
    mat <- matrix(c(3, 1, 4, 1, 5, 9, 2, 6, 5), nrow = 3, ncol = 3)

    result <- jlview_colMaxs(mat)
    expected <- apply(mat, 2, max)

    expect_false(is_jlview(result))
    expect_equal(result, expected)
})

# ── jlview_rowMedians tests ──

test_that("rowMedians matches apply(mat, 1, median) with odd columns", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    # 3 rows x 5 columns (odd number of columns)
    JuliaCall::julia_command("test_rm_odd = reshape(collect(1.0:15.0), 3, 5)")
    jl_mat <- JuliaCall::julia_eval("test_rm_odd", need_return = "Julia")
    x <- jlview(jl_mat)

    result <- jlview_rowMedians(x)
    expected <- apply(matrix(1:15, nrow = 3, ncol = 5), 1, median)

    expect_equal(length(result), 3L)
    expect_true(max(abs(result - expected)) < 1e-10)
})

test_that("rowMedians matches apply(mat, 1, median) with even columns", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    # 3 rows x 4 columns (even number of columns)
    JuliaCall::julia_command("test_rm_even = reshape(collect(1.0:12.0), 3, 4)")
    jl_mat <- JuliaCall::julia_eval("test_rm_even", need_return = "Julia")
    x <- jlview(jl_mat)

    result <- jlview_rowMedians(x)
    expected <- apply(matrix(1:12, nrow = 3, ncol = 4), 1, median)

    expect_equal(length(result), 3L)
    expect_true(max(abs(result - expected)) < 1e-10)
})

test_that("rowMedians returns named vector from rownames", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_rm_named = reshape(collect(1.0:6.0), 2, 3)")
    jl_mat <- JuliaCall::julia_eval("test_rm_named", need_return = "Julia")
    x <- jlview(jl_mat, dimnames = list(c("gene1", "gene2"), c("s1", "s2", "s3")))

    result <- jlview_rowMedians(x)

    expect_equal(names(result), c("gene1", "gene2"))
})

test_that("rowMedians on integer matrix", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_rm_int = Int32.(reshape(collect(1:12), 3, 4))")
    jl_mat <- JuliaCall::julia_eval("test_rm_int", need_return = "Julia")
    x <- jlview(jl_mat)

    result <- jlview_rowMedians(x)
    expected <- apply(matrix(1:12, nrow = 3, ncol = 4), 1, median)

    expect_equal(length(result), 3L)
    expect_true(max(abs(result - expected)) < 1e-10)
})

test_that("rowMedians on single-row matrix", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_rm_1row = reshape(collect(1.0:5.0), 1, 5)")
    jl_mat <- JuliaCall::julia_eval("test_rm_1row", need_return = "Julia")
    x <- jlview(jl_mat)

    result <- jlview_rowMedians(x)
    expected <- median(1:5)

    expect_equal(length(result), 1L)
    expect_equal(result[1], expected)
})

test_that("rowMedians on single-column matrix", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_rm_1col = reshape(collect(1.0:5.0), 5, 1)")
    jl_mat <- JuliaCall::julia_eval("test_rm_1col", need_return = "Julia")
    x <- jlview(jl_mat)

    result <- jlview_rowMedians(x)
    expected <- 1:5

    expect_equal(length(result), 5L)
    expect_true(max(abs(result - expected)) < 1e-10)
})

test_that("rowMedians on large matrix (3000x500)", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_rm_large = rand(3000, 500)")
    jl_mat <- JuliaCall::julia_eval("test_rm_large", need_return = "Julia")
    x <- jlview(jl_mat)

    result <- jlview_rowMedians(x)
    expected <- apply(as.matrix(x), 1, median)

    expect_equal(length(result), 3000L)
    expect_true(max(abs(result - expected)) < 1e-10)
})

test_that("rowMedians non-jlview fallback", {
    mat <- matrix(c(3, 1, 4, 1, 5, 9, 2, 6, 5), nrow = 3, ncol = 3)

    result <- jlview_rowMedians(mat)
    expected <- apply(mat, 1, median)

    expect_false(is_jlview(result))
    expect_equal(result, expected)
})

# ── jlview_colMeans tests ──

test_that("colMeans matches base colMeans", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_cmn_basic = reshape(collect(1.0:12.0), 3, 4)")
    jl_mat <- JuliaCall::julia_eval("test_cmn_basic", need_return = "Julia")
    x <- jlview(jl_mat)

    result <- jlview_colMeans(x)
    expected <- colMeans(matrix(1:12, nrow = 3, ncol = 4))

    expect_equal(length(result), 4L)
    expect_true(max(abs(result - expected)) < 1e-10)
})

test_that("colMeans returns named vector from colnames", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_cmn_named = reshape(collect(1.0:6.0), 2, 3)")
    jl_mat <- JuliaCall::julia_eval("test_cmn_named", need_return = "Julia")
    x <- jlview(jl_mat, dimnames = list(c("r1", "r2"), c("x", "y", "z")))

    result <- jlview_colMeans(x)

    expect_equal(names(result), c("x", "y", "z"))
})

test_that("colMeans on integer matrix", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_cmn_int = Int32.(reshape(collect(1:12), 3, 4))")
    jl_mat <- JuliaCall::julia_eval("test_cmn_int", need_return = "Julia")
    x <- jlview(jl_mat)

    result <- jlview_colMeans(x)
    expected <- colMeans(matrix(1:12, nrow = 3, ncol = 4))

    expect_equal(length(result), 4L)
    expect_true(max(abs(result - expected)) < 1e-10)
})

test_that("colMeans on single-row matrix", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_cmn_1row = reshape(collect(1.0:5.0), 1, 5)")
    jl_mat <- JuliaCall::julia_eval("test_cmn_1row", need_return = "Julia")
    x <- jlview(jl_mat)

    result <- jlview_colMeans(x)
    expected <- 1:5

    expect_equal(length(result), 5L)
    expect_true(max(abs(result - expected)) < 1e-10)
})

test_that("colMeans on single-column matrix", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_cmn_1col = reshape(collect(1.0:5.0), 5, 1)")
    jl_mat <- JuliaCall::julia_eval("test_cmn_1col", need_return = "Julia")
    x <- jlview(jl_mat)

    result <- jlview_colMeans(x)

    expect_equal(length(result), 1L)
    expect_equal(result[1], 3.0)
})

test_that("colMeans on large matrix (3000x500)", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_cmn_large = rand(3000, 500)")
    jl_mat <- JuliaCall::julia_eval("test_cmn_large", need_return = "Julia")
    x <- jlview(jl_mat)

    result <- jlview_colMeans(x)
    expected <- colMeans(as.matrix(x))

    expect_equal(length(result), 500L)
    expect_true(max(abs(result - expected)) < 1e-10)
})

test_that("colMeans non-jlview fallback", {
    mat <- matrix(1:12, nrow = 3, ncol = 4)

    result <- jlview_colMeans(mat)
    expected <- colMeans(mat)

    expect_false(is_jlview(result))
    expect_equal(result, expected)
})

# ── jlview_rowMeans tests ──

test_that("rowMeans matches base rowMeans", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_rmn_basic = reshape(collect(1.0:12.0), 3, 4)")
    jl_mat <- JuliaCall::julia_eval("test_rmn_basic", need_return = "Julia")
    x <- jlview(jl_mat)

    result <- jlview_rowMeans(x)
    expected <- rowMeans(matrix(1:12, nrow = 3, ncol = 4))

    expect_equal(length(result), 3L)
    expect_true(max(abs(result - expected)) < 1e-10)
})

test_that("rowMeans returns named vector from rownames", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_rmn_named = reshape(collect(1.0:6.0), 2, 3)")
    jl_mat <- JuliaCall::julia_eval("test_rmn_named", need_return = "Julia")
    x <- jlview(jl_mat, dimnames = list(c("g1", "g2"), c("s1", "s2", "s3")))

    result <- jlview_rowMeans(x)

    expect_equal(names(result), c("g1", "g2"))
})

test_that("rowMeans on integer matrix", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_rmn_int = Int32.(reshape(collect(1:12), 3, 4))")
    jl_mat <- JuliaCall::julia_eval("test_rmn_int", need_return = "Julia")
    x <- jlview(jl_mat)

    result <- jlview_rowMeans(x)
    expected <- rowMeans(matrix(1:12, nrow = 3, ncol = 4))

    expect_equal(length(result), 3L)
    expect_true(max(abs(result - expected)) < 1e-10)
})

test_that("rowMeans on single-row matrix", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_rmn_1row = reshape(collect(1.0:5.0), 1, 5)")
    jl_mat <- JuliaCall::julia_eval("test_rmn_1row", need_return = "Julia")
    x <- jlview(jl_mat)

    result <- jlview_rowMeans(x)
    expected <- mean(1:5)

    expect_equal(length(result), 1L)
    expect_equal(result[1], expected)
})

test_that("rowMeans on single-column matrix", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_rmn_1col = reshape(collect(1.0:5.0), 5, 1)")
    jl_mat <- JuliaCall::julia_eval("test_rmn_1col", need_return = "Julia")
    x <- jlview(jl_mat)

    result <- jlview_rowMeans(x)
    expected <- 1:5

    expect_equal(length(result), 5L)
    expect_true(max(abs(result - expected)) < 1e-10)
})

test_that("rowMeans on large matrix (3000x500)", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_rmn_large = rand(3000, 500)")
    jl_mat <- JuliaCall::julia_eval("test_rmn_large", need_return = "Julia")
    x <- jlview(jl_mat)

    result <- jlview_rowMeans(x)
    expected <- rowMeans(as.matrix(x))

    expect_equal(length(result), 3000L)
    expect_true(max(abs(result - expected)) < 1e-10)
})

test_that("rowMeans non-jlview fallback", {
    mat <- matrix(1:12, nrow = 3, ncol = 4)

    result <- jlview_rowMeans(mat)
    expected <- rowMeans(mat)

    expect_false(is_jlview(result))
    expect_equal(result, expected)
})
