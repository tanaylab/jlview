test_that("jlview creates Float64 vector with correct values", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_vec = collect(1.0:100.0)")
    jl_vec <- JuliaCall::julia_eval("test_vec", need_return = "Julia")
    x <- jlview(jl_vec)

    expected <- seq(1.0, 100.0)
    expect_true(all.equal(as.numeric(x), expected))
})

test_that("jlview preserves vector length", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_vec_len = rand(500)")
    jl_vec <- JuliaCall::julia_eval("test_vec_len", need_return = "Julia")
    x <- jlview(jl_vec)

    expect_equal(length(x), 500L)
})

test_that("jlview supports element access", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_vec_access = collect(1.0:100.0)")
    jl_vec <- JuliaCall::julia_eval("test_vec_access", need_return = "Julia")
    x <- jlview(jl_vec)

    expect_equal(x[1], 1.0)
    expect_equal(x[50], 50.0)
    expect_equal(x[100], 100.0)
})

test_that("jlview supports subsetting", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_vec_subset = collect(1.0:100.0)")
    jl_vec <- JuliaCall::julia_eval("test_vec_subset", need_return = "Julia")
    x <- jlview(jl_vec)

    subset <- x[1:10]
    expect_equal(length(subset), 10L)
    expect_equal(as.numeric(subset), seq(1.0, 10.0))
})

test_that("sum works on jlview vector", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_vec_sum = collect(1.0:100.0)")
    jl_vec <- JuliaCall::julia_eval("test_vec_sum", need_return = "Julia")
    x <- jlview(jl_vec)

    r_sum <- sum(x)
    jl_sum <- JuliaCall::julia_call("sum", jl_vec, need_return = "R")

    expect_equal(r_sum, jl_sum)
})

test_that("copy-on-write works", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_vec_cow = collect(1.0:100.0)")
    jl_vec <- JuliaCall::julia_eval("test_vec_cow", need_return = "Julia")
    x <- jlview(jl_vec)

    # Copy and modify
    y <- x
    y[1] <- 999.0

    # Original jlview should be unchanged
    expect_equal(x[1], 1.0)
    # Modified copy should have the new value
    expect_equal(y[1], 999.0)

    # Original Julia array should also be unchanged
    jl_first <- JuliaCall::julia_eval("test_vec_cow[1]", need_return = "R")
    expect_equal(jl_first, 1.0)
})
