# Test GC threshold function and its effects on memory management

test_that("jlview_set_gc_threshold changes the threshold", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    # Save the original threshold to restore later
    original <- jlview_gc_pressure()$threshold
    on.exit(jlview_set_gc_threshold(original), add = TRUE)

    jlview_set_gc_threshold(1024)

    pressure <- jlview_gc_pressure()
    expect_equal(pressure$threshold, 1024)
})

test_that("threshold can be set to various values", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    original <- jlview_gc_pressure()$threshold
    on.exit(jlview_set_gc_threshold(original), add = TRUE)

    # Set to 1 MB
    jlview_set_gc_threshold(1024 * 1024)
    expect_equal(jlview_gc_pressure()$threshold, 1024 * 1024)

    # Set to 4 GB
    jlview_set_gc_threshold(4 * 1024^3)
    expect_equal(jlview_gc_pressure()$threshold, 4 * 1024^3)
})

test_that("small threshold triggers GC on large allocation", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    original <- jlview_gc_pressure()$threshold
    on.exit(jlview_set_gc_threshold(original), add = TRUE)

    # Create some temporary jlview objects and let go of references
    for (i in 1:20) {
        JuliaCall::julia_command(paste0("_gc_thr_tmp_", i, " = rand(1000)"))
        jl <- JuliaCall::julia_eval(paste0("_gc_thr_tmp_", i), need_return = "Julia")
        tmp <- jlview(jl)
    }
    # tmp references are overwritten, but R GC hasn't run yet

    pressure_before_gc <- jlview_gc_pressure()$pinned_bytes

    # Set a very small threshold so next allocation triggers forced R GC
    jlview_set_gc_threshold(1)

    # Create a new jlview — this should trigger forced GC internally
    JuliaCall::julia_command("_gc_thr_trigger = rand(1000)")
    jl <- JuliaCall::julia_eval("_gc_thr_trigger", need_return = "Julia")
    x <- jlview(jl)

    pressure_after <- jlview_gc_pressure()$pinned_bytes

    # After GC, pinned bytes should be less than before
    # (the old temporaries should have been collected)
    expect_lt(pressure_after, pressure_before_gc)

    # Cleanup Julia vars
    for (i in 1:20) {
        JuliaCall::julia_command(paste0("_gc_thr_tmp_", i, " = nothing"))
    }
    JuliaCall::julia_command("_gc_thr_trigger = nothing")
})

test_that("threshold persists across multiple allocations", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    original <- jlview_gc_pressure()$threshold
    on.exit(jlview_set_gc_threshold(original), add = TRUE)

    jlview_set_gc_threshold(2048)

    # Create multiple jlview objects
    for (i in 1:5) {
        JuliaCall::julia_command(paste0("_gc_persist_", i, " = rand(10)"))
        jl <- JuliaCall::julia_eval(paste0("_gc_persist_", i), need_return = "Julia")
        tmp <- jlview(jl)
    }

    # Threshold should still be what we set
    expect_equal(jlview_gc_pressure()$threshold, 2048)

    # Cleanup
    for (i in 1:5) {
        JuliaCall::julia_command(paste0("_gc_persist_", i, " = nothing"))
    }
})
