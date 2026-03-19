# Create a zero-copy R sparse matrix view of a Julia SparseMatrixCSC

Creates a
[`dgCMatrix-class`](https://rdrr.io/pkg/Matrix/man/dgCMatrix-class.html)
backed by a zero-copy ALTREP vector for the nonzero values (`x` slot).
The row indices (`i` slot) and column pointers (`p` slot) are copied and
shifted from 1-based (Julia) to 0-based (R) indexing in Julia, then
returned as plain R integer vectors.

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

  Ignored. Retained for API compatibility only. Previously controlled
  lazy vs eager materialization of ALTREP index vectors, which have been
  removed in favor of simple copy+shift in Julia.

## Value

A
[`dgCMatrix-class`](https://rdrr.io/pkg/Matrix/man/dgCMatrix-class.html)
sparse matrix.

## Examples

``` r
if (FALSE) { # \dontrun{
JuliaCall::julia_setup()
JuliaCall::julia_command("using SparseArrays")
m <- JuliaCall::julia_eval("sprand(Float64, 100, 50, 0.1)")
s <- jlview_sparse(m)
class(s) # "dgCMatrix"
} # }
```
