# Test that common R operations do NOT materialize jlview ALTREP objects.
# These operations call REAL(x)/INTEGER(x) which invokes Dataptr(TRUE),
# but they only read — they should NOT trigger a copy into R's heap.

test_that("colSums does not materialize dense jlview matrix", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    m <- jlview(JuliaCall::julia_eval("randn(100, 50)", need_return = "Julia"))
    expect_false(jlview_info(m)$materialized)

    cs <- colSums(m)
    expect_true(is_jlview(m))
    expect_false(jlview_info(m)$materialized)
    expect_equal(length(cs), 50L)
})

test_that("rowSums does not materialize dense jlview matrix", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    m <- jlview(JuliaCall::julia_eval("randn(100, 50)", need_return = "Julia"))
    rs <- rowSums(m)
    expect_true(is_jlview(m))
    expect_false(jlview_info(m)$materialized)
    expect_equal(length(rs), 100L)
})

test_that("colMeans does not materialize dense jlview matrix", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    m <- jlview(JuliaCall::julia_eval("randn(100, 50)", need_return = "Julia"))
    cm <- colMeans(m)
    expect_true(is_jlview(m))
    expect_false(jlview_info(m)$materialized)
    expect_equal(length(cm), 50L)
})

test_that("rowMeans does not materialize dense jlview matrix", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    m <- jlview(JuliaCall::julia_eval("randn(100, 50)", need_return = "Julia"))
    rm <- rowMeans(m)
    expect_true(is_jlview(m))
    expect_false(jlview_info(m)$materialized)
    expect_equal(length(rm), 100L)
})

test_that("apply does not materialize dense jlview matrix", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    m <- jlview(JuliaCall::julia_eval("randn(20, 10)", need_return = "Julia"))
    a <- apply(m, 2, mean)
    expect_true(is_jlview(m))
    expect_false(jlview_info(m)$materialized)
    expect_equal(length(a), 10L)
})

test_that("matrix multiply does not materialize dense jlview matrix", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    m <- jlview(JuliaCall::julia_eval("randn(20, 10)", need_return = "Julia"))
    v <- m %*% rep(1, 10)
    expect_true(is_jlview(m))
    expect_false(jlview_info(m)$materialized)
    expect_equal(nrow(v), 20L)
})

test_that("t() does not materialize dense jlview matrix", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    m <- jlview(JuliaCall::julia_eval("randn(20, 10)", need_return = "Julia"))
    tr <- t(m)
    expect_true(is_jlview(m))
    expect_false(jlview_info(m)$materialized)
    expect_equal(dim(tr), c(10L, 20L))
})

test_that("range does not materialize dense jlview vector", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    v <- jlview(JuliaCall::julia_eval("randn(1000)", need_return = "Julia"))
    r <- range(v)
    expect_true(is_jlview(v))
    expect_false(jlview_info(v)$materialized)
    expect_equal(length(r), 2L)
})

test_that("which.min does not materialize dense jlview vector", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    v <- jlview(JuliaCall::julia_eval("randn(1000)", need_return = "Julia"))
    w <- which.min(v)
    expect_true(is_jlview(v))
    expect_false(jlview_info(v)$materialized)
    expect_true(w >= 1L && w <= 1000L)
})

test_that("sum does not materialize (uses ALTREP Sum method)", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    v <- jlview(JuliaCall::julia_eval("randn(1000)", need_return = "Julia"))
    s <- sum(v)
    expect_true(is_jlview(v))
    expect_false(jlview_info(v)$materialized)
})

test_that("mean does not materialize", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    v <- jlview(JuliaCall::julia_eval("randn(1000)", need_return = "Julia"))
    m <- mean(v)
    expect_true(is_jlview(v))
    expect_false(jlview_info(v)$materialized)
})

test_that("element access does not materialize", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    v <- jlview(JuliaCall::julia_eval("randn(1000)", need_return = "Julia"))
    x <- v[500]
    expect_true(is_jlview(v))
    expect_false(jlview_info(v)$materialized)
})

test_that("subsetting does not materialize", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    v <- jlview(JuliaCall::julia_eval("randn(1000)", need_return = "Julia"))
    x <- v[1:100]
    expect_true(is_jlview(v))
    expect_false(jlview_info(v)$materialized)
    expect_equal(length(x), 100L)
})

test_that("integer colSums does not materialize", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    m <- jlview(JuliaCall::julia_eval("Int32.(reshape(1:200, 20, 10))", need_return = "Julia"))
    cs <- colSums(m)
    expect_true(is_jlview(m))
    expect_false(jlview_info(m)$materialized)
    expect_equal(length(cs), 10L)
})

test_that("named matrix colSums does not materialize", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("using NamedArrays")
    JuliaCall::julia_command("_nm_cs = NamedArray(randn(50, 20))")
    m <- jlview_named_matrix(JuliaCall::julia_eval("_nm_cs", need_return = "Julia"))

    expect_true(is_jlview(m))
    cs <- colSums(m)
    expect_true(is_jlview(m))
    expect_false(jlview_info(m)$materialized)
    expect_equal(length(cs), 20L)
})

test_that("memory does not increase after colSums on large matrix", {
    skip_if(!JULIA_AVAILABLE, "Julia not available")

    JuliaCall::julia_command("_big_nomat = randn(5000, 1000)")
    m <- jlview(JuliaCall::julia_eval("_big_nomat", need_return = "Julia"))

    gc()
    mem_before <- gc()[2, 2]  # Vcells MB

    cs <- colSums(m)

    gc()
    mem_after <- gc()[2, 2]

    # Should not increase by more than a few MB (result vector + overhead)
    # Without the fix this would increase by ~38 MB (5000*1000*8 bytes)
    expect_true(is_jlview(m))
    expect_false(jlview_info(m)$materialized)
    expect_lt(mem_after - mem_before, 5)  # less than 5 MB increase
})
