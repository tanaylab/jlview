test_that("jlview_sparse creates dgCMatrix with correct dimensions", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("using SparseArrays")
    jl_sp <- JuliaCall::julia_eval(
        "sparse([1,2,3,1], [1,2,3,3], [1.0,2.0,3.0,4.0], 3, 3)",
        need_return = "Julia"
    )
    result <- jlview_sparse(jl_sp)

    expect_true(inherits(result, "dgCMatrix"))
    expect_equal(nrow(result), 3L)
    expect_equal(ncol(result), 3L)
})

test_that("jlview_sparse produces correct dense values", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("using SparseArrays")
    jl_sp <- JuliaCall::julia_eval(
        "sparse([1,2,3,1], [1,2,3,3], [1.0,2.0,3.0,4.0], 3, 3)",
        need_return = "Julia"
    )
    result <- jlview_sparse(jl_sp)

    expected <- matrix(
        c(
            1, 0, 0,
            0, 2, 0,
            4, 0, 3
        ),
        nrow = 3, ncol = 3
    )

    expect_equal(as.matrix(result), expected)
})

test_that("colSums and rowSums work on jlview_sparse matrix", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("using SparseArrays")
    jl_sp <- JuliaCall::julia_eval(
        "sparse([1,2,3,1], [1,2,3,3], [1.0,2.0,3.0,4.0], 3, 3)",
        need_return = "Julia"
    )
    result <- jlview_sparse(jl_sp)

    expect_equal(Matrix::colSums(result), c(1, 2, 7))
    expect_equal(Matrix::rowSums(result), c(5, 2, 3))
})

test_that("jlview_sparse matrix survives saveRDS/readRDS roundtrip", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("using SparseArrays")
    jl_sp <- JuliaCall::julia_eval(
        "sparse([1,2,3,1], [1,2,3,3], [1.0,2.0,3.0,4.0], 3, 3)",
        need_return = "Julia"
    )
    result <- jlview_sparse(jl_sp)

    tmp <- tempfile(fileext = ".rds")
    on.exit(unlink(tmp), add = TRUE)

    saveRDS(result, tmp)
    loaded <- readRDS(tmp)

    expect_true(inherits(loaded, "dgCMatrix"))
    expect_equal(nrow(loaded), 3L)
    expect_equal(ncol(loaded), 3L)

    expected <- matrix(
        c(
            1, 0, 0,
            0, 2, 0,
            4, 0, 3
        ),
        nrow = 3, ncol = 3
    )
    expect_equal(as.matrix(loaded), expected)
})
