test_that("jlview_log2p on vector matches R log2", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_log2p_vec = collect(1.0:10.0)")
    jl_vec <- JuliaCall::julia_eval("test_log2p_vec", need_return = "Julia")
    x <- jlview(jl_vec)

    result <- jlview_log2p(x)
    expected <- log2(1:10 + 1e-5)

    expect_true(is_jlview(result))
    expect_equal(length(result), 10L)
    expect_true(max(abs(as.numeric(result) - expected)) < 1e-10)
})

test_that("jlview_log2p on matrix preserves dimensions", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_log2p_mat = reshape(collect(1.0:12.0), 3, 4)")
    jl_mat <- JuliaCall::julia_eval("test_log2p_mat", need_return = "Julia")
    x <- jlview(jl_mat)

    result <- jlview_log2p(x)
    expected <- log2(matrix(1:12, nrow = 3, ncol = 4) + 1e-5)

    expect_true(is_jlview(result))
    expect_equal(dim(result), c(3L, 4L))
    expect_true(max(abs(as.numeric(result) - as.numeric(expected))) < 1e-10)
})

test_that("jlview_log2p preserves names on vector", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_log2p_named = collect(1.0:3.0)")
    jl_vec <- JuliaCall::julia_eval("test_log2p_named", need_return = "Julia")
    x <- jlview(jl_vec, names = c("a", "b", "c"))

    result <- jlview_log2p(x)

    expect_equal(names(result), c("a", "b", "c"))
    expected <- log2(1:3 + 1e-5)
    expect_true(max(abs(as.numeric(result) - expected)) < 1e-10)
})

test_that("jlview_log2p preserves dimnames on matrix", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_log2p_dmat = reshape(collect(1.0:6.0), 2, 3)")
    jl_mat <- JuliaCall::julia_eval("test_log2p_dmat", need_return = "Julia")
    x <- jlview(jl_mat, dimnames = list(c("r1", "r2"), c("c1", "c2", "c3")))

    result <- jlview_log2p(x)

    expect_equal(rownames(result), c("r1", "r2"))
    expect_equal(colnames(result), c("c1", "c2", "c3"))
})

test_that("jlview_log2p works on single element", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_log2p_single = [5.0]")
    jl_vec <- JuliaCall::julia_eval("test_log2p_single", need_return = "Julia")
    x <- jlview(jl_vec)

    result <- jlview_log2p(x)
    expected <- log2(5.0 + 1e-5)

    expect_true(is_jlview(result))
    expect_equal(length(result), 1L)
    expect_true(abs(result[1] - expected) < 1e-10)
})

test_that("jlview_log2p works on empty vector", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_log2p_empty = Float64[]")
    jl_vec <- JuliaCall::julia_eval("test_log2p_empty", need_return = "Julia")
    x <- jlview(jl_vec)

    result <- jlview_log2p(x)

    expect_true(is_jlview(result))
    expect_equal(length(result), 0L)
})

test_that("jlview_log2p handles zero values correctly", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_log2p_zero = [0.0, 0.0, 0.0]")
    jl_vec <- JuliaCall::julia_eval("test_log2p_zero", need_return = "Julia")
    x <- jlview(jl_vec)

    result <- jlview_log2p(x)
    expected <- log2(0 + 1e-5)

    expect_true(all(abs(as.numeric(result) - expected) < 1e-10))
})

test_that("jlview_log2p on large matrix is correct", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_log2p_large = rand(1000, 100)")
    jl_mat <- JuliaCall::julia_eval("test_log2p_large", need_return = "Julia")
    x <- jlview(jl_mat)

    result <- jlview_log2p(x)
    expected <- log2(as.numeric(x) + 1e-5)

    expect_true(is_jlview(result))
    expect_equal(dim(result), c(1000L, 100L))
    expect_true(max(abs(as.numeric(result) - expected)) < 1e-10)
})

test_that("jlview_log2p result is a jlview", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_log2p_isjl = collect(1.0:5.0)")
    jl_vec <- JuliaCall::julia_eval("test_log2p_isjl", need_return = "Julia")
    x <- jlview(jl_vec)

    result <- jlview_log2p(x)

    expect_true(is_jlview(result))
})

test_that("jlview_log2p numeric accuracy", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    vals <- c(0.001, 0.01, 0.1, 1.0, 10.0, 100.0, 1000.0)
    JuliaCall::julia_command(
        paste0("test_log2p_acc = [", paste(vals, collapse = ", "), "]")
    )
    jl_vec <- JuliaCall::julia_eval("test_log2p_acc", need_return = "Julia")
    x <- jlview(jl_vec)

    result <- jlview_log2p(x)
    expected <- log2(vals + 1e-5)

    expect_true(max(abs(as.numeric(result) - expected)) < 1e-10)
})

test_that("jlview_log2p non-jlview fallback works", {
    # Should work on regular R vectors without Julia
    vec <- c(1.0, 2.0, 3.0, 4.0, 5.0)
    result <- jlview_log2p(vec)
    expected <- log2(vec + 1e-5)

    expect_false(is_jlview(result))
    expect_equal(result, expected)
})

test_that("jlview_log2p non-jlview fallback works on matrix", {
    mat <- matrix(1:12, nrow = 3, ncol = 4)
    result <- jlview_log2p(mat)
    expected <- log2(mat + 1e-5)

    expect_false(is_jlview(result))
    expect_equal(result, expected)
    expect_equal(dim(result), c(3L, 4L))
})

test_that("jlview_log2p with scalar = 0", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_log2p_s0 = collect(1.0:5.0)")
    jl_vec <- JuliaCall::julia_eval("test_log2p_s0", need_return = "Julia")
    x <- jlview(jl_vec)

    result <- jlview_log2p(x, scalar = 0)
    expected <- log2(1:5)

    expect_true(max(abs(as.numeric(result) - expected)) < 1e-10)
})

test_that("jlview_log2p with scalar = 1", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_log2p_s1 = collect(0.0:4.0)")
    jl_vec <- JuliaCall::julia_eval("test_log2p_s1", need_return = "Julia")
    x <- jlview(jl_vec)

    result <- jlview_log2p(x, scalar = 1)
    expected <- log2(0:4 + 1)

    expect_true(max(abs(as.numeric(result) - expected)) < 1e-10)
})

test_that("jlview_log2p with custom scalar 1e-5", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_log2p_sc = collect(1.0:5.0)")
    jl_vec <- JuliaCall::julia_eval("test_log2p_sc", need_return = "Julia")
    x <- jlview(jl_vec)

    result <- jlview_log2p(x, scalar = 1e-5)
    expected <- log2(1:5 + 1e-5)

    expect_true(max(abs(as.numeric(result) - expected)) < 1e-10)
})
