test_that("jlview_release prevents further access", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_rel_access = collect(1.0:100.0)")
    jl_vec <- JuliaCall::julia_eval("test_rel_access", need_return = "Julia")
    x <- jlview(jl_vec)

    # Should work before release
    expect_equal(x[1], 1.0)

    jlview_release(x)

    # Accessing after release should error
    expect_error(x[1])
})

test_that("double release doesn't crash", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_rel_double = collect(1.0:10.0)")
    jl_vec <- JuliaCall::julia_eval("test_rel_double", need_return = "Julia")
    x <- jlview(jl_vec)

    jlview_release(x)
    # Second release should not error or crash
    expect_no_error(jlview_release(x))
})

test_that("is_jlview returns correct values", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_is_jlview = collect(1.0:10.0)")
    jl_vec <- JuliaCall::julia_eval("test_is_jlview", need_return = "Julia")
    x <- jlview(jl_vec)

    expect_true(is_jlview(x))
    expect_false(is_jlview(c(1.0, 2.0, 3.0)))
    expect_false(is_jlview(1:10))
    expect_false(is_jlview("hello"))
})
