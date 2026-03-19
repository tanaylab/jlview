# Set the GC pressure threshold

When total pinned bytes exceeds this threshold, jlview forces an R
garbage collection to reclaim stale ALTREP objects. Default is 10GB.

## Usage

``` r
jlview_set_gc_threshold(bytes)
```

## Arguments

- bytes:

  Threshold in bytes (numeric)

## Value

Invisible `NULL`
