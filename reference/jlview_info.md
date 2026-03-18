# Get information about a jlview object

Returns metadata about a jlview ALTREP vector including the Julia
element type, length, writeability, and release status.

## Usage

``` r
jlview_info(x)
```

## Arguments

- x:

  A jlview ALTREP vector

## Value

A named list with components:

- type:

  Julia element type (e.g., "Float64")

- length:

  Number of elements

- writeable:

  Whether the view allows direct writes

- released:

  Whether the view has been released

- materialized:

  Whether COW materialization has occurred
