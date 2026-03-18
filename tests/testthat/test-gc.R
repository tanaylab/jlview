test_that("memory pressure tracking works", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    pressure_before <- jlview_gc_pressure()
    expect_true(is.list(pressure_before))
    expect_true("pinned_bytes" %in% names(pressure_before))
    expect_true("threshold" %in% names(pressure_before))

    # Create a jlview object to increase pressure
    JuliaCall::julia_command("test_gc_vec = rand(10000)")
    jl_vec <- JuliaCall::julia_eval("test_gc_vec", need_return = "Julia")
    x <- jlview(jl_vec)

    pressure_after <- jlview_gc_pressure()
    # 10000 Float64 = 80000 bytes
    expect_gte(pressure_after$pinned_bytes, pressure_before$pinned_bytes + 80000)
})

test_that("explicit release works", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_gc_release = rand(10000)")
    jl_vec <- JuliaCall::julia_eval("test_gc_release", need_return = "Julia")
    x <- jlview(jl_vec)

    pressure_before <- jlview_gc_pressure()

    jlview_release(x)

    pressure_after <- jlview_gc_pressure()
    # After release, pinned bytes should drop by at least 80000
    expect_lte(pressure_after$pinned_bytes, pressure_before$pinned_bytes - 80000)
})
