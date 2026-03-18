# Test writeable mode: shared mutation and COW behavior

test_that("writeable jlview is recognized as jlview", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("_wrt_basic = collect(1.0:10.0)")
    jl_vec <- JuliaCall::julia_eval("_wrt_basic", need_return = "Julia")
    x <- jlview(jl_vec, writeable = TRUE)

    expect_true(is_jlview(x))
})

test_that("writeable jlview reports writeable=TRUE in info", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("_wrt_info = collect(1.0:10.0)")
    jl_vec <- JuliaCall::julia_eval("_wrt_info", need_return = "Julia")
    x <- jlview(jl_vec, writeable = TRUE)

    info <- jlview_info(x)
    expect_true(info$writeable)
})

test_that("write to writeable view changes the value", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("_wrt_write = collect(1.0:10.0)")
    jl_vec <- JuliaCall::julia_eval("_wrt_write", need_return = "Julia")
    x <- jlview(jl_vec, writeable = TRUE)

    x[1] <- 999.0

    expect_equal(x[1], 999.0)
})

test_that("write to writeable view does not trigger COW (still is_jlview)", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("_wrt_no_cow = collect(1.0:10.0)")
    jl_vec <- JuliaCall::julia_eval("_wrt_no_cow", need_return = "Julia")
    x <- jlview(jl_vec, writeable = TRUE)

    x[1] <- 999.0

    # After writing to a writeable view, it should still be a jlview (no COW)
    expect_true(is_jlview(x))
    info <- jlview_info(x)
    expect_false(info$materialized)
})

test_that("writeable view mutation is visible from Julia side", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("_wrt_jl_visible = collect(1.0:10.0)")
    jl_vec <- JuliaCall::julia_eval("_wrt_jl_visible", need_return = "Julia")
    x <- jlview(jl_vec, writeable = TRUE)

    x[1] <- 777.0

    # The Julia array should see the change (shared memory)
    jl_first <- JuliaCall::julia_eval("_wrt_jl_visible[1]", need_return = "R")
    expect_equal(jl_first, 777.0)
})

test_that("read-only view (default) triggers COW on write", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("_wrt_ro_cow = collect(1.0:10.0)")
    jl_vec <- JuliaCall::julia_eval("_wrt_ro_cow", need_return = "Julia")
    x <- jlview(jl_vec, writeable = FALSE)

    # Verify it starts as read-only jlview
    expect_true(is_jlview(x))
    info_before <- jlview_info(x)
    expect_false(info_before$writeable)

    # Write triggers COW: R makes a copy, modifies the copy
    x[1] <- 999.0

    # The R value should have the new value
    expect_equal(x[1], 999.0)

    # The original Julia array should be unchanged
    jl_first <- JuliaCall::julia_eval("_wrt_ro_cow[1]", need_return = "R")
    expect_equal(jl_first, 1.0)
})

test_that("default jlview reports writeable=FALSE", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    jl_vec <- JuliaCall::julia_eval("collect(1.0:5.0)", need_return = "Julia")
    x <- jlview(jl_vec)

    info <- jlview_info(x)
    expect_false(info$writeable)
})

test_that("writeable Int32 vector allows direct writes", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("_wrt_i32 = Int32[1, 2, 3, 4, 5]")
    jl_vec <- JuliaCall::julia_eval("_wrt_i32", need_return = "Julia")
    x <- jlview(jl_vec, writeable = TRUE)

    x[3] <- 42L

    expect_equal(x[3], 42L)
    expect_true(is_jlview(x))
})

test_that("writeable matrix allows element assignment", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("_wrt_mat = ones(3, 3)")
    jl_mat <- JuliaCall::julia_eval("_wrt_mat", need_return = "Julia")
    m <- jlview(jl_mat, writeable = TRUE)

    m[2, 2] <- 99.0

    expect_equal(m[2, 2], 99.0)
    expect_true(is_jlview(m))
})
