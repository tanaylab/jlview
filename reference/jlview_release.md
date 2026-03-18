# Explicitly release a jlview object

Unpins the Julia array immediately, freeing memory without waiting for
R's garbage collector. After release, accessing the data will error.

## Usage

``` r
jlview_release(x)
```

## Arguments

- x:

  A jlview ALTREP vector

## Value

Invisible `NULL`
