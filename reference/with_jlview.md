# Use a jlview object within a scope, releasing it on exit

Creates a jlview object and ensures it is released when the scope exits,
even if an error occurs. This prevents memory leaks from forgotten
releases.

## Usage

``` r
with_jlview(
  julia_array,
  expr,
  writeable = FALSE,
  names = NULL,
  dimnames = NULL
)
```

## Arguments

- julia_array:

  A JuliaObject referencing a Julia array

- expr:

  An expression to evaluate with the jlview object bound to `.x`

- writeable:

  Passed to
  [`jlview`](https://tanaylab.github.io/jlview/reference/jlview.md)

- names:

  Passed to
  [`jlview`](https://tanaylab.github.io/jlview/reference/jlview.md)

- dimnames:

  Passed to
  [`jlview`](https://tanaylab.github.io/jlview/reference/jlview.md)

## Value

The result of evaluating `expr`

## Examples

``` r
if (FALSE) { # \dontrun{
JuliaCall::julia_setup()
JuliaCall::julia_command("big = randn(100000)")
result <- with_jlview(JuliaCall::julia_eval("big"), {
    c(mean(.x), sd(.x))
})
# .x is automatically released here
} # }
```
