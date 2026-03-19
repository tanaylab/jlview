test_that("jlview_t swaps dimensions", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_t_dims = reshape(collect(1.0:12.0), 3, 4)")
    jl_mat <- JuliaCall::julia_eval("test_t_dims", need_return = "Julia")
    x <- jlview(jl_mat)

    result <- jlview_t(x)

    expect_equal(dim(result), c(4L, 3L))
    expect_equal(nrow(result), 4L)
    expect_equal(ncol(result), 3L)
})

test_that("jlview_t values: t(mat)[i,j] == mat[j,i]", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_t_vals = reshape(collect(1.0:12.0), 3, 4)")
    jl_mat <- JuliaCall::julia_eval("test_t_vals", need_return = "Julia")
    x <- jlview(jl_mat)

    result <- jlview_t(x)

    # Check every element: result[i,j] == x[j,i]
    for (i in 1:4) {
        for (j in 1:3) {
            expect_equal(result[i, j], x[j, i])
        }
    }
})

test_that("jlview_t swaps dimnames", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_t_named = reshape(collect(1.0:6.0), 2, 3)")
    jl_mat <- JuliaCall::julia_eval("test_t_named", need_return = "Julia")
    x <- jlview(jl_mat, dimnames = list(c("r1", "r2"), c("c1", "c2", "c3")))

    result <- jlview_t(x)

    expect_equal(rownames(result), c("c1", "c2", "c3"))
    expect_equal(colnames(result), c("r1", "r2"))
    expect_equal(dim(result), c(3L, 2L))
})

test_that("jlview_t on square matrix", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_t_sq = reshape(collect(1.0:9.0), 3, 3)")
    jl_mat <- JuliaCall::julia_eval("test_t_sq", need_return = "Julia")
    x <- jlview(jl_mat)

    result <- jlview_t(x)

    expect_equal(dim(result), c(3L, 3L))
    for (i in 1:3) {
        for (j in 1:3) {
            expect_equal(result[i, j], x[j, i])
        }
    }
})

test_that("jlview_t single row becomes single column", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_t_row = reshape(collect(1.0:5.0), 1, 5)")
    jl_mat <- JuliaCall::julia_eval("test_t_row", need_return = "Julia")
    x <- jlview(jl_mat)

    result <- jlview_t(x)

    expect_equal(dim(result), c(5L, 1L))
    for (i in 1:5) {
        expect_equal(result[i, 1], x[1, i])
    }
})

test_that("jlview_t single column becomes single row", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_t_col = reshape(collect(1.0:5.0), 5, 1)")
    jl_mat <- JuliaCall::julia_eval("test_t_col", need_return = "Julia")
    x <- jlview(jl_mat)

    result <- jlview_t(x)

    expect_equal(dim(result), c(1L, 5L))
    for (j in 1:5) {
        expect_equal(result[1, j], x[j, 1])
    }
})

test_that("jlview_t double transpose recovers original values", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_t_dbl = reshape(collect(1.0:20.0), 4, 5)")
    jl_mat <- JuliaCall::julia_eval("test_t_dbl", need_return = "Julia")
    x <- jlview(jl_mat)

    result <- jlview_t(jlview_t(x))

    expect_equal(dim(result), dim(x))
    expect_true(max(abs(as.numeric(result) - as.numeric(x))) < 1e-10)
})

test_that("jlview_t result is jlview ALTREP", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_t_altrep = reshape(collect(1.0:6.0), 2, 3)")
    jl_mat <- JuliaCall::julia_eval("test_t_altrep", need_return = "Julia")
    x <- jlview(jl_mat)

    result <- jlview_t(x)

    expect_true(is_jlview(result))
})

test_that("jlview_t matches R t() numerically", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_t_acc = reshape(Float64[0.1, 2.5, 3.7, 100.0, 0.001, 99.99], 2, 3)")
    jl_mat <- JuliaCall::julia_eval("test_t_acc", need_return = "Julia")
    x <- jlview(jl_mat)

    result <- jlview_t(x)
    r_mat <- matrix(as.numeric(x), nrow = nrow(x), ncol = ncol(x))
    expected <- t(r_mat)

    expect_equal(dim(result), dim(expected))
    expect_true(max(abs(as.numeric(result) - as.numeric(expected))) < 1e-10)
})

test_that("jlview_t on large matrix (5000x1000)", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_t_large = rand(5000, 1000)")
    jl_mat <- JuliaCall::julia_eval("test_t_large", need_return = "Julia")
    x <- jlview(jl_mat)

    result <- jlview_t(x)

    expect_true(is_jlview(result))
    expect_equal(dim(result), c(1000L, 5000L))

    # Spot-check a few values
    expect_equal(result[1, 1], x[1, 1])
    expect_equal(result[500, 2500], x[2500, 500])
    expect_equal(result[1000, 5000], x[5000, 1000])
})

test_that("jlview_t non-jlview fallback works on regular R matrix", {
    mat <- matrix(1:12, nrow = 3, ncol = 4)
    result <- jlview_t(mat)
    expected <- t(mat)

    expect_false(is_jlview(result))
    expect_equal(result, expected)
    expect_equal(dim(result), c(4L, 3L))
})

test_that("jlview_t integer matrix preserves values", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_t_int = reshape(Int32[1, 2, 3, 4, 5, 6], 2, 3)")
    jl_mat <- JuliaCall::julia_eval("test_t_int", need_return = "Julia")
    x <- jlview(jl_mat)

    result <- jlview_t(x)

    expect_true(is_jlview(result))
    expect_equal(dim(result), c(3L, 2L))
    for (i in 1:3) {
        for (j in 1:2) {
            expect_equal(result[i, j], x[j, i])
        }
    }
})
