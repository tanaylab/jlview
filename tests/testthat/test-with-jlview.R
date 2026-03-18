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
