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
