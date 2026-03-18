# Create a zero-copy R view of a named Julia matrix

Creates a zero-copy ALTREP view of a Julia NamedArray matrix, preserving
row and column names as dimnames.

## Usage

``` r
jlview_named_matrix(julia_named_matrix)
```

## Arguments

- julia_named_matrix:

  A JuliaObject referencing a Julia NamedArray matrix

## Value

An ALTREP matrix with dimnames set from the Julia NamedArray

## Examples

``` r
if (interactive()) {
    JuliaCall::julia_setup()
    JuliaCall::julia_command("using NamedArrays")
    m <- JuliaCall::julia_eval('NamedArray(randn(3,2), (["a","b","c"], ["x","y"]))')
    x <- jlview_named_matrix(m)
    rownames(x) # returns c("a", "b", "c")
    colnames(x) # returns c("x", "y")
}
```
