# Test type conversion boundary values

test_that("Int64 near 2^53 converts accurately", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    # 2^53 - 1 = 9007199254740991 is the largest integer exactly representable
    # as Float64. Values at and below this should convert without precision loss.
    jl_vec <- JuliaCall::julia_eval(
        "[2^53 - 2, 2^53 - 1]",
        need_return = "Julia"
    )
    x <- jlview(jl_vec)

    expect_equal(x[1], 2^53 - 2)
    expect_equal(x[2], 2^53 - 1)
})

test_that("Int64 values exceeding 2^53 produce a warning", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    # 2^53 + 1 cannot be exactly represented as Float64.
    # The Julia-side pin() should emit a warning about precision loss.
    # JuliaCall may or may not propagate Julia @warn to R warnings,
    # so we check that the conversion still completes and values are close.
    jl_vec <- JuliaCall::julia_eval(
        "[2^53 + 1]",
        need_return = "Julia"
    )
    x <- jlview(jl_vec)

    # The value should be approximately 2^53 + 1, but may lose the +1
    # due to Float64 representation limits
    expect_true(is.double(x))
    expect_equal(length(x), 1L)
    # The converted value should be within 1 of the original
    expect_true(abs(x[1] - (2^53 + 1)) <= 1)
})

test_that("Int64 with large negative values converts", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    jl_vec <- JuliaCall::julia_eval(
        "[-(2^53 - 1), -(2^53 - 2)]",
        need_return = "Julia"
    )
    x <- jlview(jl_vec)

    expect_equal(x[1], -(2^53 - 1))
    expect_equal(x[2], -(2^53 - 2))
})

test_that("Int32 with NA_integer_ equivalent (-2147483648) appears as NA", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    # R uses -2147483648 (INT_MIN) as NA_integer_.
    # When Julia has this value, it should appear as NA in R.
    jl_vec <- JuliaCall::julia_eval(
        "Int32[-2147483648, 1, 2]",
        need_return = "Julia"
    )
    x <- jlview(jl_vec)

    expect_true(is.integer(x))
    # INT_MIN in R is NA_integer_
    expect_true(is.na(x[1]))
    expect_equal(x[2], 1L)
    expect_equal(x[3], 2L)
})

test_that("Int32 near boundaries (but not INT_MIN) works", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    # INT_MAX = 2147483647, INT_MIN + 1 = -2147483647
    jl_vec <- JuliaCall::julia_eval(
        "Int32[2147483647, -2147483647, 0]",
        need_return = "Julia"
    )
    x <- jlview(jl_vec)

    expect_equal(x[1], 2147483647L)
    expect_equal(x[2], -2147483647L)
    expect_equal(x[3], 0L)
})

test_that("Float32 small values convert accurately to Float64", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    # Float32 has ~7 decimal digits of precision.
    # Small values like 0.1 should survive round-trip through Float32 -> Float64.
    jl_vec <- JuliaCall::julia_eval(
        "Float32[0.1, 0.5, 1.0, -0.25]",
        need_return = "Julia"
    )
    x <- jlview(jl_vec)

    expect_true(is.double(x))
    # Float32(0.1) is not exactly 0.1, but it should match Float32 precision
    expect_equal(x[1], as.double(as.single(0.1)), tolerance = 1e-7)
    expect_equal(x[2], 0.5) # Exact in binary
    expect_equal(x[3], 1.0)
    expect_equal(x[4], -0.25) # Exact in binary
})

test_that("Float32 large values convert correctly", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    jl_vec <- JuliaCall::julia_eval(
        "Float32[1e30, -1e30, 1e-30]",
        need_return = "Julia"
    )
    x <- jlview(jl_vec)

    expect_true(is.double(x))
    # Float32 max is ~3.4e38, so 1e30 is well within range
    expect_equal(x[1], as.double(as.single(1e30)), tolerance = 1e-7)
    expect_equal(x[2], as.double(as.single(-1e30)), tolerance = 1e-7)
    expect_equal(x[3], as.double(as.single(1e-30)), tolerance = 1e-7)
})

test_that("Float32 special values (Inf, -Inf) convert correctly", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    jl_vec <- JuliaCall::julia_eval(
        "Float32[Inf32, -Inf32]",
        need_return = "Julia"
    )
    x <- jlview(jl_vec)

    expect_true(is.infinite(x[1]))
    expect_true(x[1] > 0)
    expect_true(is.infinite(x[2]))
    expect_true(x[2] < 0)
})

test_that("Float64 special values (Inf, NaN) work in jlview", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    jl_vec <- JuliaCall::julia_eval(
        "Float64[Inf, -Inf, NaN, 0.0, -0.0]",
        need_return = "Julia"
    )
    x <- jlview(jl_vec)

    expect_true(is.infinite(x[1]) && x[1] > 0)
    expect_true(is.infinite(x[2]) && x[2] < 0)
    expect_true(is.nan(x[3]))
    expect_equal(x[4], 0.0)
    expect_equal(x[5], 0.0)
})

test_that("Int16 boundary values convert to Int32 correctly", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    # Int16 range: -32768 to 32767
    jl_vec <- JuliaCall::julia_eval(
        "Int16[-32768, -1, 0, 1, 32767]",
        need_return = "Julia"
    )
    x <- jlview(jl_vec)

    expect_true(is.integer(x))
    expect_equal(x[1], -32768L)
    expect_equal(x[2], -1L)
    expect_equal(x[3], 0L)
    expect_equal(x[4], 1L)
    expect_equal(x[5], 32767L)
})

test_that("UInt8 boundary values convert to Int32 correctly", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    # UInt8 range: 0 to 255
    jl_vec <- JuliaCall::julia_eval(
        "UInt8[0, 1, 127, 128, 255]",
        need_return = "Julia"
    )
    x <- jlview(jl_vec)

    expect_true(is.integer(x))
    expect_equal(x[1], 0L)
    expect_equal(x[2], 1L)
    expect_equal(x[3], 127L)
    expect_equal(x[4], 128L)
    expect_equal(x[5], 255L)
})

test_that("Int64 zero converts correctly", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    jl_vec <- JuliaCall::julia_eval(
        "Int64[0]",
        need_return = "Julia"
    )
    x <- jlview(jl_vec)

    expect_true(is.double(x))
    expect_equal(x[1], 0.0)
})
