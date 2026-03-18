test_that("Float32 array converts to Float64 with values preserved", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    jl_vec <- JuliaCall::julia_eval("Float32[1.5, 2.5, 3.5]", need_return = "Julia")
    x <- jlview(jl_vec)

    expect_equal(as.numeric(x), c(1.5, 2.5, 3.5))
    expect_true(is.double(x))
})

test_that("Int64 array (small values) converts to Float64 correctly", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    jl_vec <- JuliaCall::julia_eval("Int64[1, 2, 3]", need_return = "Julia")
    x <- jlview(jl_vec)

    expect_equal(as.numeric(x), c(1.0, 2.0, 3.0))
    expect_true(is.double(x))
})

test_that("Int16 array converts to Int32 correctly", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    jl_vec <- JuliaCall::julia_eval("Int16[10, 20, 30]", need_return = "Julia")
    x <- jlview(jl_vec)

    expect_equal(as.integer(x), c(10L, 20L, 30L))
    expect_true(is.integer(x))
})

test_that("Bool array falls back to standard copy", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    jl_vec <- JuliaCall::julia_eval("[true, false, true]", need_return = "Julia")
    x <- expect_warning(jlview(jl_vec), "not supported for zero-copy")

    # expect_warning returns the warning condition, so re-capture the value
    x <- suppressWarnings(jlview(jl_vec))
    expect_equal(x, c(TRUE, FALSE, TRUE))
    expect_true(is.logical(x))
    expect_false(is_jlview(x))
})
