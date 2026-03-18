# Test writeable mode behavior
#
# NOTE: R's `[<-` subassignment always duplicates ALTREP objects regardless of
# the writeable flag. The writeable flag controls Dataptr(x, TRUE) at the C
# level, which matters for C code calling DATAPTR directly. At the R level,
# both writeable and read-only jlviews trigger COW on subassignment.
# The practical use case for writeable=TRUE is C extensions that need to write
# to Julia memory via DATAPTR.

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

test_that("default jlview reports writeable=FALSE", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    jl_vec <- JuliaCall::julia_eval("collect(1.0:5.0)", need_return = "Julia")
    x <- jlview(jl_vec)

    info <- jlview_info(x)
    expect_false(info$writeable)
})

test_that("R subassignment on writeable jlview produces correct value (via COW)", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("_wrt_write = collect(1.0:10.0)")
    jl_vec <- JuliaCall::julia_eval("_wrt_write", need_return = "Julia")
    x <- jlview(jl_vec, writeable = TRUE)

    x[1] <- 999.0

    # The R value should have the new value (whether via direct write or COW)
    expect_equal(x[1], 999.0)
})

test_that("R subassignment on read-only jlview triggers COW, Julia unchanged", {
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

test_that("writeable jlview reads correctly before any write", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("_wrt_read = collect(1.0:10.0)")
    jl_vec <- JuliaCall::julia_eval("_wrt_read", need_return = "Julia")
    x <- jlview(jl_vec, writeable = TRUE)

    expect_equal(x[1], 1.0)
    expect_equal(x[10], 10.0)
    expect_equal(sum(x), 55.0)
    expect_equal(length(x), 10L)
})

test_that("writeable Int32 jlview works correctly", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("_wrt_i32 = Int32[1, 2, 3, 4, 5]")
    jl_vec <- JuliaCall::julia_eval("_wrt_i32", need_return = "Julia")
    x <- jlview(jl_vec, writeable = TRUE)

    expect_true(is_jlview(x))
    expect_equal(x[3], 3L)
    expect_equal(sum(x), 15L)
})

test_that("writeable matrix reads correctly", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("_wrt_mat = ones(3, 3)")
    jl_mat <- JuliaCall::julia_eval("_wrt_mat", need_return = "Julia")
    m <- jlview(jl_mat, writeable = TRUE)

    expect_true(is_jlview(m))
    expect_equal(dim(m), c(3L, 3L))
    expect_equal(m[2, 2], 1.0)
    expect_equal(sum(m), 9.0)
})
