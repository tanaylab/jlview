test_that("mass allocation triggers GC pressure", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")
    pressure_before <- jlview_gc_pressure()
    for (i in 1:500) {
        JuliaCall::julia_command(paste0("_stress_", i, " = rand(100)"))
        jl <- JuliaCall::julia_eval(paste0("_stress_", i), need_return = "Julia")
        x <- jlview(jl)
        # Don't hold reference — let GC collect
    }
    gc() # Force R GC
    pressure_after <- jlview_gc_pressure()
    # Pinned bytes should NOT be 500*100*8 — most should be collected
    expect_lt(pressure_after$pinned_bytes, 500 * 100 * 8)
    # Cleanup
    for (i in 1:500) {
        JuliaCall::julia_command(paste0("_stress_", i, " = nothing"))
    }
})

test_that("release produces clean error on subsequent access", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")
    JuliaCall::julia_command("_stress_rel = rand(1000)")
    jl <- JuliaCall::julia_eval("_stress_rel", need_return = "Julia")
    x <- jlview(jl)
    expect_equal(length(x), 1000L)
    jlview_release(x)
    expect_error(sum(x), "released")
    expect_error(x[1], "released")
    expect_error(mean(x), "released")
})

test_that("jlview_info reports released state correctly", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")
    JuliaCall::julia_command("_stress_info = rand(100)")
    jl <- JuliaCall::julia_eval("_stress_info", need_return = "Julia")
    x <- jlview(jl)
    info <- jlview_info(x)
    expect_false(info$released)
    jlview_release(x)
    info2 <- jlview_info(x)
    expect_true(info2$released)
})

test_that("interleaved creation and GC cycles work", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")
    for (batch in 1:5) {
        for (i in 1:50) {
            JuliaCall::julia_command(paste0("_batch_", batch, "_", i, " = rand(100)"))
            jl <- JuliaCall::julia_eval(paste0("_batch_", batch, "_", i), need_return = "Julia")
            x <- jlview(jl)
        }
        gc()
    }
    # Should complete without crash
    expect_true(TRUE)
    # Cleanup Julia vars
    for (batch in 1:5) {
        for (i in 1:50) {
            JuliaCall::julia_command(paste0("_batch_", batch, "_", i, " = nothing"))
        }
    }
})

test_that("mixed types survive GC correctly", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")
    JuliaCall::julia_command("_kept_f64 = collect(1.0:100.0)")
    JuliaCall::julia_command("_kept_i32 = Int32.(1:100)")
    f64 <- jlview(JuliaCall::julia_eval("_kept_f64", need_return = "Julia"))
    i32 <- jlview(JuliaCall::julia_eval("_kept_i32", need_return = "Julia"))
    # Create and discard many temporary objects
    for (i in 1:100) {
        JuliaCall::julia_command(paste0("_tmp_", i, " = rand(100)"))
        tmp <- jlview(JuliaCall::julia_eval(paste0("_tmp_", i), need_return = "Julia"))
    }
    gc()
    # Kept references should still be valid
    expect_equal(f64[1], 1.0)
    expect_equal(f64[100], 100.0)
    expect_equal(i32[1], 1L)
    expect_equal(i32[100], 100L)
})
