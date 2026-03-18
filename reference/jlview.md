# Create a zero-copy R view of a Julia array

Creates an ALTREP vector (or matrix, if 2D+) backed by Julia memory. The
resulting R object shares the same memory as the Julia array, avoiding
data copying. Modifications to the R object trigger copy-on-write
(unless `writeable = TRUE`).

## Usage

``` r
jlview(julia_array, writeable = FALSE, names = NULL, dimnames = NULL)
```

## Arguments

- julia_array:

  A JuliaObject referencing a Julia array

- writeable:

  If `TRUE`, allow R to write directly to Julia's memory. Use with
  caution — this enables shared mutation. Default `FALSE`.

- names:

  Optional character vector of names to attach to the result. Attached
  atomically during construction to avoid ALTREP materialization.

- dimnames:

  Optional list of dimnames to attach to the result. Attached atomically
  during construction to avoid ALTREP materialization.

## Value

An ALTREP vector backed by Julia memory, or a standard R vector if the
Julia type is not supported for zero-copy.

## Examples

``` r
if (interactive()) {
    JuliaCall::julia_setup()
    # Create a Julia array and view it in R without copying
    JuliaCall::julia_command("x = randn(1000)")
    x <- jlview(JuliaCall::julia_eval("x"))
    sum(x) # operates directly on Julia memory
}
```
