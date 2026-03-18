# Create a zero-copy R view of a named Julia vector

Creates a zero-copy ALTREP view of a Julia NamedArray vector, preserving
the axis names.

## Usage

``` r
jlview_named_vector(julia_named_array)
```

## Arguments

- julia_named_array:

  A JuliaObject referencing a Julia NamedArray vector

## Value

An ALTREP vector with names set from the Julia NamedArray

## Examples

``` r
if (interactive()) {
    JuliaCall::julia_setup()
    JuliaCall::julia_command("using NamedArrays")
    v <- JuliaCall::julia_eval('NamedArray([1.0, 2.0, 3.0], (["a", "b", "c"],))')
    x <- jlview_named_vector(v)
    names(x) # returns c("a", "b", "c")
}
```
