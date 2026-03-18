# Create a zero-copy R sparse matrix view of a Julia SparseMatrixCSC

Creates a
[`dgCMatrix-class`](https://rdrr.io/pkg/Matrix/man/dgCMatrix-class.html)
backed by zero-copy ALTREP vectors for the nonzero values (`x` slot) and
ALTREP index vectors for the row indices (`i` slot) and column pointers
(`p` slot). The Julia-to-R index shift (1-based to 0-based) is handled
lazily by the ALTREP index class.

## Usage

``` r
jlview_sparse(julia_sparse_matrix, lazy_indices = FALSE)
```

## Arguments

- julia_sparse_matrix:

  A JuliaObject referencing a Julia `SparseMatrixCSC`. The value type
  must be supported for zero-copy (Float64, Float32, Int32, Int64,
  Int16, UInt8).

- lazy_indices:

  If `FALSE` (the default), the index vectors (`i` and `p`) are eagerly
  materialized into standard R integer vectors after construction. This
  avoids repeated lazy -1 shifts on every element access and is
  recommended for matrices that will be accessed many times. If `TRUE`,
  indices remain as lazy ALTREP views that compute the shift on-the-fly.

## Value

A
[`dgCMatrix-class`](https://rdrr.io/pkg/Matrix/man/dgCMatrix-class.html)
sparse matrix.

## Examples

``` r
if (interactive()) {
    JuliaCall::julia_setup()
    JuliaCall::julia_command("using SparseArrays")
    m <- JuliaCall::julia_eval("sprand(Float64, 100, 50, 0.1)")
    s <- jlview_sparse(m)
    class(s) # "dgCMatrix"
}
```
