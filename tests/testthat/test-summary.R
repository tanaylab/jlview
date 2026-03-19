test_that("sum() on jlview works", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")
    JuliaCall::julia_command("_sum_test = collect(1.0:1000.0)")
    jl <- JuliaCall::julia_eval("_sum_test", need_return = "Julia")
    x <- jlview(jl)
    expect_equal(sum(x), sum(1:1000))
})

test_that("min/max on jlview work", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")
    JuliaCall::julia_command("_minmax_test = Float64[3.0, 1.0, 4.0, 1.5, 9.0, 2.6]")
    jl <- JuliaCall::julia_eval("_minmax_test", need_return = "Julia")
    x <- jlview(jl)
    expect_equal(min(x), 1.0)
    expect_equal(max(x), 9.0)
})

test_that("sum/min/max work after materialization", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")
    JuliaCall::julia_command("_sum_mat = collect(1.0:100.0)")
    jl <- JuliaCall::julia_eval("_sum_mat", need_return = "Julia")
    x <- jlview(jl)
    x[1] <- 999.0
    expect_equal(sum(x), sum(c(999.0, 2:100)))
})

test_that("sum with na.rm=TRUE falls back to R and handles NaN", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")
    JuliaCall::julia_command("_sum_nan = Float64[1.0, NaN, 3.0]")
    jl <- JuliaCall::julia_eval("_sum_nan", need_return = "Julia")
    x <- jlview(jl)

    # na.rm=FALSE: NaN propagates (both Julia and R agree)
    expect_true(is.nan(sum(x)))

    # na.rm=TRUE: should skip NaN and return 4.0
    expect_equal(sum(x, na.rm = TRUE), 4.0)
})

test_that("min/max with na.rm=TRUE handle NaN correctly", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")
    JuliaCall::julia_command("_mm_nan = Float64[5.0, NaN, 2.0, 8.0]")
    jl <- JuliaCall::julia_eval("_mm_nan", need_return = "Julia")
    x <- jlview(jl)

    expect_equal(min(x, na.rm = TRUE), 2.0)
    expect_equal(max(x, na.rm = TRUE), 8.0)
})
