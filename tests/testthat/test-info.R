# Test jlview_info() comprehensively: all 5 fields

test_that("jlview_info returns all expected fields", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    jl_vec <- JuliaCall::julia_eval("collect(1.0:10.0)", need_return = "Julia")
    x <- jlview(jl_vec)

    info <- jlview_info(x)

    expect_true(is.list(info))
    expect_true("type" %in% names(info))
    expect_true("length" %in% names(info))
    expect_true("writeable" %in% names(info))
    expect_true("released" %in% names(info))
    expect_true("materialized" %in% names(info))
})

test_that("type is 'Float64' for Float64 array", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    jl_vec <- JuliaCall::julia_eval("collect(1.0:5.0)", need_return = "Julia")
    x <- jlview(jl_vec)

    info <- jlview_info(x)
    expect_equal(info$type, "Float64")
})

test_that("type is 'Int32' for Int32 array", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    jl_vec <- JuliaCall::julia_eval("Int32[1, 2, 3]", need_return = "Julia")
    x <- jlview(jl_vec)

    info <- jlview_info(x)
    expect_equal(info$type, "Int32")
})

test_that("type is 'Int32' for UInt8 array (converted to Int32)", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    jl_vec <- JuliaCall::julia_eval("UInt8[1, 2, 3]", need_return = "Julia")
    x <- jlview(jl_vec)

    info <- jlview_info(x)
    # UInt8 is converted to Int32 during pin(), so the ALTREP type is Int32
    expect_equal(info$type, "Int32")
})

test_that("length matches actual vector length", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    jl_vec <- JuliaCall::julia_eval("collect(1.0:250.0)", need_return = "Julia")
    x <- jlview(jl_vec)

    info <- jlview_info(x)
    expect_equal(info$length, 250L)
    expect_equal(info$length, length(x))
})

test_that("length is correct for single element", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    jl_vec <- JuliaCall::julia_eval("Float64[99.0]", need_return = "Julia")
    x <- jlview(jl_vec)

    info <- jlview_info(x)
    expect_equal(info$length, 1L)
})

test_that("length is correct for empty vector", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    jl_vec <- JuliaCall::julia_eval("Float64[]", need_return = "Julia")
    x <- jlview(jl_vec)

    info <- jlview_info(x)
    expect_equal(info$length, 0L)
})

test_that("writeable is FALSE by default", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    jl_vec <- JuliaCall::julia_eval("collect(1.0:10.0)", need_return = "Julia")
    x <- jlview(jl_vec)

    info <- jlview_info(x)
    expect_false(info$writeable)
})

test_that("writeable is TRUE when requested", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    jl_vec <- JuliaCall::julia_eval("collect(1.0:10.0)", need_return = "Julia")
    x <- jlview(jl_vec, writeable = TRUE)

    info <- jlview_info(x)
    expect_true(info$writeable)
})

test_that("released is FALSE initially", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    jl_vec <- JuliaCall::julia_eval("collect(1.0:10.0)", need_return = "Julia")
    x <- jlview(jl_vec)

    info <- jlview_info(x)
    expect_false(info$released)
})

test_that("released becomes TRUE after jlview_release", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("_info_release = collect(1.0:10.0)")
    jl_vec <- JuliaCall::julia_eval("_info_release", need_return = "Julia")
    x <- jlview(jl_vec)

    jlview_release(x)

    info <- jlview_info(x)
    expect_true(info$released)
})

test_that("materialized is FALSE initially", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    jl_vec <- JuliaCall::julia_eval("collect(1.0:10.0)", need_return = "Julia")
    x <- jlview(jl_vec)

    info <- jlview_info(x)
    expect_false(info$materialized)
})

test_that("R subassignment replaces jlview with standard vector (COW)", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("_info_mat = collect(1.0:10.0)")
    jl_vec <- JuliaCall::julia_eval("_info_mat", need_return = "Julia")
    x <- jlview(jl_vec)

    # R's [<- always duplicates ALTREP objects, replacing them with standard vectors.
    # After subassignment, x is no longer a jlview.
    x[1] <- 999.0

    expect_false(is_jlview(x))
    expect_equal(x[1], 999.0)
})

test_that("all info fields are consistent for a matrix", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    jl_mat <- JuliaCall::julia_eval("rand(5, 10)", need_return = "Julia")
    x <- jlview(jl_mat)

    info <- jlview_info(x)
    expect_equal(info$type, "Float64")
    expect_equal(info$length, 50L)
    expect_false(info$writeable)
    expect_false(info$released)
    expect_false(info$materialized)
})
