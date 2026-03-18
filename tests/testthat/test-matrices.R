test_that("jlview creates Float64 matrix", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_mat = rand(10, 20)")
    jl_mat <- JuliaCall::julia_eval("test_mat", need_return = "Julia")
    m <- jlview(jl_mat)

    expect_equal(dim(m), c(10L, 20L))
})

test_that("matrix operations work", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_mat_ops = ones(5, 3)")
    jl_mat <- JuliaCall::julia_eval("test_mat_ops", need_return = "Julia")
    m <- jlview(jl_mat)

    cs <- colSums(m)
    expect_equal(cs, rep(5.0, 3))

    rs <- rowSums(m)
    expect_equal(rs, rep(3.0, 5))
})

test_that("nrow and ncol work", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("test_mat_dims = rand(10, 20)")
    jl_mat <- JuliaCall::julia_eval("test_mat_dims", need_return = "Julia")
    m <- jlview(jl_mat)

    expect_equal(nrow(m), 10L)
    expect_equal(ncol(m), 20L)
})
