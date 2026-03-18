test_that("named vector has correct names", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("using NamedArrays")
    jl_vec <- JuliaCall::julia_eval(
        'NamedArray([1.0, 2.0, 3.0], (["a", "b", "c"],))',
        need_return = "Julia"
    )
    x <- jlview_named_vector(jl_vec)

    expect_equal(names(x), c("a", "b", "c"))
})

test_that("named vector has correct values", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("using NamedArrays")
    jl_vec <- JuliaCall::julia_eval(
        'NamedArray([1.0, 2.0, 3.0], (["a", "b", "c"],))',
        need_return = "Julia"
    )
    x <- jlview_named_vector(jl_vec)

    expect_equal(as.numeric(x), c(1.0, 2.0, 3.0))
})

test_that("named matrix has correct rownames and colnames", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("using NamedArrays")
    jl_mat <- JuliaCall::julia_eval(
        'NamedArray([1.0 4.0; 2.0 5.0; 3.0 6.0], (["r1", "r2", "r3"], ["c1", "c2"]))',
        need_return = "Julia"
    )
    x <- jlview_named_matrix(jl_mat)

    expect_equal(rownames(x), c("r1", "r2", "r3"))
    expect_equal(colnames(x), c("c1", "c2"))
})

test_that("named matrix colSums works correctly", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("using NamedArrays")
    jl_mat <- JuliaCall::julia_eval(
        'NamedArray([1.0 4.0; 2.0 5.0; 3.0 6.0], (["r1", "r2", "r3"], ["c1", "c2"]))',
        need_return = "Julia"
    )
    x <- jlview_named_matrix(jl_mat)

    expected_colsums <- c(c1 = 6.0, c2 = 15.0)
    expect_equal(colSums(x), expected_colsums)
})
