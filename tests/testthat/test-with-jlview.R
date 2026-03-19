test_that("with_jlview releases on normal exit", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")
    JuliaCall::julia_command("_wj_normal = rand(1000)")
    jl <- JuliaCall::julia_eval("_wj_normal", need_return = "Julia")

    result <- with_jlview(jl, {
        expect_true(is_jlview(.x))
        sum(.x)
    })
    expect_true(is.numeric(result))
})

test_that("with_jlview releases on error", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")
    JuliaCall::julia_command("_wj_err = rand(100)")
    jl <- JuliaCall::julia_eval("_wj_err", need_return = "Julia")

    pressure_before <- jlview_gc_pressure()
    expect_error(
        with_jlview(jl, {
            stop("deliberate error")
        }),
        "deliberate error"
    )
    pressure_after <- jlview_gc_pressure()
    # Memory should have been freed despite the error
    expect_lte(pressure_after$pinned_bytes, pressure_before$pinned_bytes)
})

test_that("with_jlview can access caller's local variables", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")
    JuliaCall::julia_command("_wj_scope = collect(1.0:10.0)")
    jl <- JuliaCall::julia_eval("_wj_scope", need_return = "Julia")

    # y is a local variable in this test function's frame
    y <- 100
    result <- with_jlview(jl, {
        sum(.x) + y
    })
    expect_equal(result, sum(1:10) + 100)
})

test_that("with_jlview can access caller's locals from nested function", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")
    JuliaCall::julia_command("_wj_nested = Float64[1.0, 2.0, 3.0]")
    jl <- JuliaCall::julia_eval("_wj_nested", need_return = "Julia")

    helper <- function(jl_obj) {
        multiplier <- 10
        with_jlview(jl_obj, {
            sum(.x) * multiplier
        })
    }
    expect_equal(helper(jl), 60)
})
