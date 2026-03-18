# Get current GC pressure information

Returns the current amount of Julia memory pinned by jlview objects and
the threshold at which forced GC is triggered.

## Usage

``` r
jlview_gc_pressure()
```

## Value

A list with `pinned_bytes` and `threshold`
