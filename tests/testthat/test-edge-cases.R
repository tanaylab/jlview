# Test edge cases: empty arrays, single element, 3D arrays, unusual names

test_that("empty Float64 vector has length 0", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    jl_vec <- JuliaCall::julia_eval("Float64[]", need_return = "Julia")
    x <- jlview(jl_vec)

    expect_equal(length(x), 0L)
    expect_true(is_jlview(x))
})

test_that("sum of empty vector is 0", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    jl_vec <- JuliaCall::julia_eval("Float64[]", need_return = "Julia")
    x <- jlview(jl_vec)

    expect_equal(sum(x), 0)
})

test_that("subsetting empty vector returns empty", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    jl_vec <- JuliaCall::julia_eval("Float64[]", need_return = "Julia")
    x <- jlview(jl_vec)

    subset <- x[integer(0)]
    expect_equal(length(subset), 0L)
})

test_that("empty Int32 vector has length 0", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    jl_vec <- JuliaCall::julia_eval("Int32[]", need_return = "Julia")
    x <- jlview(jl_vec)

    expect_equal(length(x), 0L)
    expect_true(is.integer(x))
})

test_that("empty matrix (0x0) has correct dim", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    jl_mat <- JuliaCall::julia_eval(
        "reshape(Float64[], 0, 0)",
        need_return = "Julia"
    )
    x <- jlview(jl_mat)

    expect_equal(dim(x), c(0L, 0L))
    expect_equal(length(x), 0L)
})

test_that("single element vector works correctly", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    jl_vec <- JuliaCall::julia_eval("Float64[42.0]", need_return = "Julia")
    x <- jlview(jl_vec)

    expect_equal(length(x), 1L)
    expect_equal(x[1], 42.0)
    expect_equal(sum(x), 42.0)
    expect_true(is_jlview(x))
})

test_that("single element Int32 vector works correctly", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    jl_vec <- JuliaCall::julia_eval("Int32[7]", need_return = "Julia")
    x <- jlview(jl_vec)

    expect_equal(length(x), 1L)
    expect_equal(x[1], 7L)
    expect_equal(sum(x), 7L)
    expect_true(is.integer(x))
})

test_that("3D array (tensor) has correct dimensions", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    jl_arr <- JuliaCall::julia_eval(
        "reshape(collect(1.0:24.0), 2, 3, 4)",
        need_return = "Julia"
    )
    x <- jlview(jl_arr)

    expect_equal(dim(x), c(2L, 3L, 4L))
    expect_equal(length(x), 24L)
})

test_that("3D array element access matches Julia column-major order", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    jl_arr <- JuliaCall::julia_eval(
        "reshape(collect(1.0:24.0), 2, 3, 4)",
        need_return = "Julia"
    )
    x <- jlview(jl_arr)

    # Both R and Julia are column-major, so linear indexing should match
    expect_equal(x[1], 1.0)
    expect_equal(x[24], 24.0)
    # Multi-dimensional indexing: x[row, col, slice]
    # In Julia/R column-major: element [1,1,1] = 1, [2,1,1] = 2, [1,2,1] = 3
    expect_equal(x[1, 1, 1], 1.0)
    expect_equal(x[2, 1, 1], 2.0)
    expect_equal(x[1, 2, 1], 3.0)
})

test_that("vector with names containing dots works", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    jl_vec <- JuliaCall::julia_eval(
        "Float64[1.0, 2.0, 3.0]",
        need_return = "Julia"
    )
    nms <- c("gene.1", "gene.2", "gene.3")
    x <- jlview(jl_vec, names = nms)

    expect_equal(names(x), nms)
    expect_equal(x["gene.1"], c("gene.1" = 1.0))
})

test_that("vector with names containing spaces works", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    jl_vec <- JuliaCall::julia_eval(
        "Float64[10.0, 20.0, 30.0]",
        need_return = "Julia"
    )
    nms <- c("a b", "c d", "e f")
    x <- jlview(jl_vec, names = nms)

    expect_equal(names(x), nms)
    expect_equal(as.numeric(x), c(10.0, 20.0, 30.0))
})

test_that("vector with names containing brackets works", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    jl_vec <- JuliaCall::julia_eval(
        "Float64[1.0, 2.0, 3.0]",
        need_return = "Julia"
    )
    nms <- c("cell [A]", "cell [B]", "cell [C]")
    x <- jlview(jl_vec, names = nms)

    expect_equal(names(x), nms)
})

test_that("very long names work", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    jl_vec <- JuliaCall::julia_eval(
        "Float64[1.0, 2.0]",
        need_return = "Julia"
    )
    long_name <- paste(rep("abcdefghij", 100), collapse = "")
    nms <- c(long_name, "short")
    x <- jlview(jl_vec, names = nms)

    expect_equal(names(x), nms)
    expect_equal(nchar(names(x)[1]), 1000L)
})

test_that("matrix with 0 rows but >0 columns", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    jl_mat <- JuliaCall::julia_eval(
        "reshape(Float64[], 0, 5)",
        need_return = "Julia"
    )
    x <- jlview(jl_mat)

    expect_equal(dim(x), c(0L, 5L))
    expect_equal(length(x), 0L)
})

test_that("matrix with >0 rows but 0 columns", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    jl_mat <- JuliaCall::julia_eval(
        "reshape(Float64[], 5, 0)",
        need_return = "Julia"
    )
    x <- jlview(jl_mat)

    expect_equal(dim(x), c(5L, 0L))
    expect_equal(length(x), 0L)
})

test_that("9D+ arrays are rejected with an error", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    jl_arr <- JuliaCall::julia_eval(
        "reshape(collect(1.0:512.0), ntuple(_ -> 2, 9))",
        need_return = "Julia"
    )
    expect_error(jlview(jl_arr), "more than 8 dimensions")
})
