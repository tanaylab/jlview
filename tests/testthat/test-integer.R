test_that("jlview creates Int32 vector with correct values", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    jl_vec <- JuliaCall::julia_eval("Int32[1, 2, 3, 4, 5]", need_return = "Julia")
    x <- jlview(jl_vec)

    expect_equal(as.integer(x), 1L:5L)
})

test_that("Int32 vector has correct length", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    jl_vec <- JuliaCall::julia_eval("Int32[1, 2, 3, 4, 5]", need_return = "Julia")
    x <- jlview(jl_vec)

    expect_equal(length(x), 5L)
})

test_that("Int32 vector supports element access", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    jl_vec <- JuliaCall::julia_eval("Int32[10, 20, 30, 40, 50]", need_return = "Julia")
    x <- jlview(jl_vec)

    expect_equal(x[1], 10L)
    expect_equal(x[5], 50L)
})

test_that("Int32 vector supports subsetting", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    jl_vec <- JuliaCall::julia_eval("Int32[1, 2, 3, 4, 5]", need_return = "Julia")
    x <- jlview(jl_vec)

    subset <- x[1:3]
    expect_equal(length(subset), 3L)
    expect_equal(as.integer(subset), 1L:3L)
})

test_that("sum works on Int32 vector with integer arithmetic", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    jl_vec <- JuliaCall::julia_eval("Int32[1, 2, 3, 4, 5]", need_return = "Julia")
    x <- jlview(jl_vec)

    expect_equal(sum(x), 15L)
    expect_true(is.integer(sum(x)))
})

test_that("Int32 vector copy-on-write works", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_int32_cow = Int32[1, 2, 3, 4, 5]")
    jl_vec <- JuliaCall::julia_eval("test_int32_cow", need_return = "Julia")
    x <- jlview(jl_vec)

    # Copy and modify
    y <- x
    y[1] <- 999L

    # Original jlview should be unchanged
    expect_equal(x[1], 1L)
    # Modified copy should have the new value
    expect_equal(y[1], 999L)

    # Original Julia array should also be unchanged
    jl_first <- JuliaCall::julia_eval("test_int32_cow[1]", need_return = "R")
    expect_equal(jl_first, 1L)
})

test_that("jlview_info reports type Int32", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    jl_vec <- JuliaCall::julia_eval("Int32[1, 2, 3, 4, 5]", need_return = "Julia")
    x <- jlview(jl_vec)

    info <- jlview_info(x)
    expect_equal(info$type, "Int32")
})

test_that("Int32 vector returns TRUE for is.integer()", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    jl_vec <- JuliaCall::julia_eval("Int32[1, 2, 3, 4, 5]", need_return = "Julia")
    x <- jlview(jl_vec)

    expect_true(is.integer(x))
})

test_that("Int32 matrix has correct dimensions", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    jl_mat <- JuliaCall::julia_eval("Int32[1 2; 3 4; 5 6]", need_return = "Julia")
    x <- jlview(jl_mat)

    expect_equal(dim(x), c(3L, 2L))
})

test_that("Int32 matrix rowSums works correctly", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    jl_mat <- JuliaCall::julia_eval("Int32[1 2; 3 4; 5 6]", need_return = "Julia")
    x <- jlview(jl_mat)

    expect_equal(rowSums(x), c(3L, 7L, 11L))
})

test_that("Int32 matrix colSums works correctly", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    jl_mat <- JuliaCall::julia_eval("Int32[1 2; 3 4; 5 6]", need_return = "Julia")
    x <- jlview(jl_mat)

    expect_equal(colSums(x), c(9L, 12L))
})
