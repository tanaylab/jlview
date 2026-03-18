# Zero-Copy Julia Arrays in R with jlview

## Introduction

When working with Julia arrays from R via JuliaCall, every transfer
copies data. For a 10,000 x 1,000 Float64 matrix, that means allocating
76 MB on the R side and spending time on a memcpy. If you are iterating
on exploratory analysis or building a pipeline that shuttles arrays back
and forth, those copies add up fast.

**jlview** eliminates that overhead using R’s ALTREP (Alternative
Representations) framework. Instead of copying,
[`jlview()`](https://tanaylab.github.io/jlview/reference/jlview.md)
returns a lightweight R vector whose data pointer points directly into
Julia’s memory. R operations like
[`sum()`](https://rdrr.io/r/base/sum.html), subsetting, and
[`colMeans()`](https://rdrr.io/r/base/colSums.html) read from Julia’s
buffer with zero additional allocation.

|                        | Latency          | R Memory       |
|------------------------|------------------|----------------|
| **jlview (zero-copy)** | 0.02 ms          | 0.1 MB         |
| **copy (collect)**     | 0.44 ms          | 76.3 MB        |
| **Improvement**        | **22.6x faster** | **99.9% less** |

*Benchmark: 10K x 1K named Float64 matrix*

## Getting Started

Install jlview from GitHub:

``` r
# install.packages("remotes")
remotes::install_github("tanaylab/jlview")
```

Before using jlview, initialize the Julia runtime via JuliaCall:

``` r
library(jlview)
JuliaCall::julia_setup()
```

The `julia_setup()` call is required once per R session. jlview will
automatically load its Julia-side support module when you first call
[`jlview()`](https://tanaylab.github.io/jlview/reference/jlview.md).

## Dense Arrays

### Vectors

Create a Julia vector and wrap it in an ALTREP view:

``` r
JuliaCall::julia_command("v = randn(100_000)")
x <- jlview(JuliaCall::julia_eval("v"))

length(x)    # 100000
sum(x)       # computed directly from Julia memory
x[1:5]       # subsetting works as usual
```

### Matrices

Two-dimensional Julia arrays become R matrices with proper dimensions:

``` r
JuliaCall::julia_command("M = randn(1000, 500)")
m <- jlview(JuliaCall::julia_eval("M"))

dim(m)       # [1] 1000  500
m[1:3, 1:3]  # subset rows and columns
colSums(m)   # column sums, no copy
```

### Verifying Zero-Copy

You can confirm that no R-side allocation occurred by checking
`is.altrep()`:

``` r
.Internal(inspect(x))
# Should show ALTREP wrapper, not a materialized REALSXP
```

## Type Handling

jlview supports the following Julia element types:

| Julia type | R type      | Strategy                                    |
|------------|-------------|---------------------------------------------|
| `Float64`  | `numeric`   | Direct zero-copy                            |
| `Int32`    | `integer`   | Direct zero-copy                            |
| `Float32`  | `numeric`   | Convert to Float64 in Julia, then zero-copy |
| `Int64`    | `numeric`   | Convert to Float64 in Julia, then zero-copy |
| `Int16`    | `integer`   | Convert to Int32 in Julia, then zero-copy   |
| `UInt8`    | `integer`   | Convert to Int32 in Julia, then zero-copy   |
| `Bool`     | `logical`   | Full copy (layout incompatible)             |
| `String[]` | `character` | Full copy (layout incompatible)             |

The conversion strategy is deliberate. Types like Float32 and Int64 do
not have a direct R counterpart with matching memory layout. jlview
converts them once on the Julia side into a layout-compatible type
(Float64 or Int32), pins the converted array, and then creates a
zero-copy view of that. The one-time conversion cost is small compared
to copying across runtimes.

For Bool and String arrays, the memory layouts are fundamentally
incompatible (Julia Bool is 1 byte, R logical is 4 bytes; Julia strings
are GC-managed objects). These fall back to JuliaCall’s standard copy
path, and
[`jlview()`](https://tanaylab.github.io/jlview/reference/jlview.md) will
emit a warning.

## Named Arrays

Julia’s NamedArrays package provides named dimensions. jlview has
dedicated functions that preserve these names without triggering ALTREP
materialization.

### Named Vectors

``` r
JuliaCall::julia_command("using NamedArrays")
JuliaCall::julia_command('nv = NamedArray([10.0, 20.0, 30.0], (["a", "b", "c"],))')
x <- jlview_named_vector(JuliaCall::julia_eval("nv"))

names(x)     # [1] "a" "b" "c"
x["b"]       # 20, still zero-copy for the data
```

### Named Matrices

``` r
JuliaCall::julia_command('nm = NamedArray(randn(3, 2), (["r1","r2","r3"], ["c1","c2"]))')
m <- jlview_named_matrix(JuliaCall::julia_eval("nm"))

rownames(m)  # [1] "r1" "r2" "r3"
colnames(m)  # [1] "c1" "c2"
m["r1", "c2"]
```

Names are attached atomically during ALTREP construction. This is
important because setting [`names()`](https://rdrr.io/r/base/names.html)
or [`dimnames()`](https://rdrr.io/r/base/dimnames.html) on an existing
ALTREP vector would normally trigger materialization (a full copy),
defeating the purpose. By passing names through
`jlview(..., names = ...)` or `jlview(..., dimnames = ...)`, the names
are set on the ALTREP object before R ever inspects the data.

## Sparse Matrices

Julia’s `SparseMatrixCSC` maps naturally to R’s `dgCMatrix` from the
Matrix package.
[`jlview_sparse()`](https://tanaylab.github.io/jlview/reference/jlview_sparse.md)
constructs a dgCMatrix where the nonzero values (`x` slot) are backed by
a zero-copy ALTREP view of Julia’s `nzval` array.

``` r
JuliaCall::julia_command("using SparseArrays")
JuliaCall::julia_command("sp = sprand(Float64, 10000, 5000, 0.01)")
s <- jlview_sparse(JuliaCall::julia_eval("sp"))

class(s)     # [1] "dgCMatrix"
dim(s)       # [1] 10000  5000
Matrix::nnzero(s)
```

The row indices (`i` slot) and column pointers (`p` slot) require a
1-to-0 index shift (Julia is 1-based, dgCMatrix is 0-based). By default
(`lazy_indices = FALSE`), these are eagerly materialized into standard R
integer vectors after construction. This avoids repeated on-the-fly
subtraction during element access and is recommended for matrices that
will be read many times.

If you are constructing many sparse matrices and only accessing them
briefly, you can set `lazy_indices = TRUE` to keep the indices as lazy
ALTREP views that compute the shift on demand.

## Memory Management

jlview pins Julia arrays in a global dictionary to prevent Julia’s
garbage collector from reclaiming them while R holds a reference. This
means Julia memory is held as long as the R ALTREP object exists.

### Three-Layer Defense

1.  **Pinning dictionary** – Each array is stored in
    `JlviewSupport.PINNED` with a unique ID. The C finalizer on the R
    ALTREP object calls `unpin()` when R garbage-collects the wrapper.

2.  **GC pressure tracking** – jlview tracks total pinned bytes and
    reports them to R via `R_AdjustExternalMemory()`. When pinned memory
    exceeds a threshold (default 2 GB), jlview forces an R
    [`gc()`](https://rdrr.io/r/base/gc.html) to reclaim stale ALTREP
    objects.

3.  **Explicit release** – For tight control, call
    [`jlview_release()`](https://tanaylab.github.io/jlview/reference/jlview_release.md)
    to immediately unpin the array without waiting for R’s GC.

### Explicit Release

``` r
m <- jlview(JuliaCall::julia_eval("randn(10000, 1000)"))
# ... use m ...
jlview_release(m)
# m is now invalid; accessing it will error
```

### Scoped Release

[`with_jlview()`](https://tanaylab.github.io/jlview/reference/with_jlview.md)
guarantees release even if an error occurs:

``` r
result <- with_jlview(JuliaCall::julia_eval("randn(100000)"), {
    c(mean(.x), sd(.x))
})
# .x is automatically released here, result is a plain R vector
```

### Tuning GC Pressure

``` r
# Check current state
jlview_gc_pressure()
# $pinned_bytes
# [1] 80000000
# $threshold
# [1] 2147483648

# Lower the threshold to 500 MB
jlview_set_gc_threshold(500e6)
```

## Copy-on-Write Semantics

jlview objects follow R’s standard copy-on-write (COW) semantics. Read
operations (subsetting, aggregation, printing) are zero-copy. Write
operations trigger materialization: R allocates a fresh buffer, copies
the data from Julia, and the ALTREP wrapper is replaced by a standard R
vector.

``` r
x <- jlview(JuliaCall::julia_eval("collect(1.0:5.0)"))
y <- x           # y and x share Julia memory, no copy
sum(y)            # zero-copy read

y[1] <- 999.0     # WRITE: triggers materialization
# y is now a standard R numeric vector (copy of Julia data, modified)
# x still points to Julia memory, unchanged
```

This is identical to how R treats any shared vector – jlview does not
introduce new semantics. The only difference is that before
materialization, the backing store is Julia memory instead of R memory.

## Serialization

jlview objects can be saved with
[`saveRDS()`](https://rdrr.io/r/base/readRDS.html) and restored with
[`readRDS()`](https://rdrr.io/r/base/readRDS.html). On save, the data is
materialized into a standard R vector (since Julia memory cannot be
serialized). On load, you get back a regular R vector.

``` r
x <- jlview(JuliaCall::julia_eval("randn(1000)"))
saveRDS(x, "my_vector.rds")

# In a new session (no Julia needed):
y <- readRDS("my_vector.rds")
class(y)  # "numeric" -- a plain R vector
```

This means serialization always works correctly, but the zero-copy
property is not preserved across save/load cycles.

## Known Limitations

- **`NA_integer_` collision** – R uses `INT_MIN` (-2147483648) to
  represent `NA_integer_`. If a Julia Int32 array contains this exact
  value, R will interpret it as NA. There is no workaround short of
  avoiding this sentinel value in Julia integer arrays.

- **Int64 precision loss** – Julia Int64 values outside the range
  +/-(2^53 - 1) lose precision when converted to Float64. jlview emits a
  warning if this is detected, but the conversion still proceeds.

- **Bool and String always copy** – Julia’s `Bool` (1 byte) is
  incompatible with R’s `logical` (4 bytes), and Julia strings are
  GC-managed objects with no contiguous memory layout that R can point
  to. These types always fall back to a full copy via JuliaCall.

- **Write-back not supported** – Modifications to jlview objects do not
  propagate back to Julia. Writes trigger R’s copy-on-write, producing
  an independent R vector.

- **Single-session lifetime** – jlview objects are tied to the Julia
  runtime in the current R session. They cannot be shared across
  processes or serialized without materialization.
