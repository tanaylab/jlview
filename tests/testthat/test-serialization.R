test_that("saveRDS/readRDS roundtrip works", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_ser = collect(1.0:100.0)")
    jl_vec <- JuliaCall::julia_eval("test_ser", need_return = "Julia")
    x <- jlview(jl_vec)

    tmp <- tempfile(fileext = ".rds")
    on.exit(unlink(tmp), add = TRUE)

    saveRDS(x, tmp)
    y <- readRDS(tmp)

    # Values should match
    expect_equal(as.numeric(y), as.numeric(x))
    expect_equal(length(y), length(x))
})

test_that("deserialized object is standard vector", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_ser_std = collect(1.0:50.0)")
    jl_vec <- JuliaCall::julia_eval("test_ser_std", need_return = "Julia")
    x <- jlview(jl_vec)

    tmp <- tempfile(fileext = ".rds")
    on.exit(unlink(tmp), add = TRUE)

    saveRDS(x, tmp)
    y <- readRDS(tmp)

    # After deserialization, it should be a regular R vector, not ALTREP/jlview
    expect_false(is_jlview(y))
    # Should still be numeric
    expect_true(is.numeric(y))
})
