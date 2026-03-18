# Test sparse matrix edge cases

test_that("empty sparse matrix (0 nonzeros) creates valid dgCMatrix", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("using SparseArrays")
    jl_sp <- JuliaCall::julia_eval(
        "sparse(Int[], Int[], Float64[], 5, 5)",
        need_return = "Julia"
    )
    result <- jlview_sparse(jl_sp)

    expect_true(inherits(result, "dgCMatrix"))
    expect_equal(nrow(result), 5L)
    expect_equal(ncol(result), 5L)
    # All elements should be zero
    expect_equal(Matrix::nnzero(result), 0L)
    expect_equal(sum(result), 0.0)
})

test_that("empty sparse matrix converts to dense zero matrix", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("using SparseArrays")
    jl_sp <- JuliaCall::julia_eval(
        "sparse(Int[], Int[], Float64[], 3, 4)",
        need_return = "Julia"
    )
    result <- jlview_sparse(jl_sp)

    dense <- as.matrix(result)
    expect_equal(dense, matrix(0, nrow = 3, ncol = 4))
})

test_that("rectangular sparse matrix (nrow > ncol)", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("using SparseArrays")
    jl_sp <- JuliaCall::julia_eval(
        "sprand(100, 50, 0.01)",
        need_return = "Julia"
    )
    result <- jlview_sparse(jl_sp)

    expect_true(inherits(result, "dgCMatrix"))
    expect_equal(nrow(result), 100L)
    expect_equal(ncol(result), 50L)
})

test_that("rectangular sparse matrix (nrow < ncol)", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("using SparseArrays")
    jl_sp <- JuliaCall::julia_eval(
        "sprand(20, 80, 0.05)",
        need_return = "Julia"
    )
    result <- jlview_sparse(jl_sp)

    expect_true(inherits(result, "dgCMatrix"))
    expect_equal(nrow(result), 20L)
    expect_equal(ncol(result), 80L)
})

test_that("1-column sparse matrix works", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("using SparseArrays")
    jl_sp <- JuliaCall::julia_eval(
        "sparse([1, 3, 5], [1, 1, 1], [10.0, 20.0, 30.0], 5, 1)",
        need_return = "Julia"
    )
    result <- jlview_sparse(jl_sp)

    expect_true(inherits(result, "dgCMatrix"))
    expect_equal(nrow(result), 5L)
    expect_equal(ncol(result), 1L)
    expect_equal(as.matrix(result), matrix(c(10, 0, 20, 0, 30), nrow = 5, ncol = 1))
})

test_that("1-row sparse matrix works", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("using SparseArrays")
    jl_sp <- JuliaCall::julia_eval(
        "sparse([1, 1, 1], [1, 3, 5], [1.0, 2.0, 3.0], 1, 5)",
        need_return = "Julia"
    )
    result <- jlview_sparse(jl_sp)

    expect_true(inherits(result, "dgCMatrix"))
    expect_equal(nrow(result), 1L)
    expect_equal(ncol(result), 5L)
    expect_equal(as.matrix(result), matrix(c(1, 0, 2, 0, 3), nrow = 1, ncol = 5))
})

test_that("lazy_indices=TRUE creates valid dgCMatrix", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("using SparseArrays")
    jl_sp <- JuliaCall::julia_eval(
        "sparse([1,2,3,1], [1,2,3,3], [1.0,2.0,3.0,4.0], 3, 3)",
        need_return = "Julia"
    )
    result <- jlview_sparse(jl_sp, lazy_indices = TRUE)

    expect_true(inherits(result, "dgCMatrix"))
    expect_equal(nrow(result), 3L)
    expect_equal(ncol(result), 3L)
})

test_that("lazy_indices=TRUE produces correct values", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("using SparseArrays")
    jl_sp <- JuliaCall::julia_eval(
        "sparse([1,2,3,1], [1,2,3,3], [1.0,2.0,3.0,4.0], 3, 3)",
        need_return = "Julia"
    )
    result <- jlview_sparse(jl_sp, lazy_indices = TRUE)

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

test_that("lazy_indices=TRUE supports colSums and rowSums", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("using SparseArrays")
    jl_sp <- JuliaCall::julia_eval(
        "sparse([1,2,3,1], [1,2,3,3], [1.0,2.0,3.0,4.0], 3, 3)",
        need_return = "Julia"
    )
    result <- jlview_sparse(jl_sp, lazy_indices = TRUE)

    expect_equal(Matrix::colSums(result), c(1, 2, 7))
    expect_equal(Matrix::rowSums(result), c(5, 2, 3))
})

test_that("large sparse matrix with low density works", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("using SparseArrays")
    jl_sp <- JuliaCall::julia_eval(
        "sprand(1000, 1000, 0.001)",
        need_return = "Julia"
    )
    result <- jlview_sparse(jl_sp)

    expect_true(inherits(result, "dgCMatrix"))
    expect_equal(nrow(result), 1000L)
    expect_equal(ncol(result), 1000L)
    # Very sparse: ~1000 nonzeros expected on average
    expect_lt(Matrix::nnzero(result), 5000L)
})

test_that("sparse matrix serialization roundtrip preserves data", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("using SparseArrays")
    jl_sp <- JuliaCall::julia_eval(
        "sparse([1, 3], [1, 2], [5.0, 10.0], 3, 3)",
        need_return = "Julia"
    )
    result <- jlview_sparse(jl_sp)

    tmp <- tempfile(fileext = ".rds")
    on.exit(unlink(tmp), add = TRUE)

    saveRDS(result, tmp)
    loaded <- readRDS(tmp)

    expect_equal(as.matrix(loaded), as.matrix(result))
})
