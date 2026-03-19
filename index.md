# jlview — Zero-Copy Julia↔︎R Arrays via ALTREP

jlview provides zero-copy R views of Julia-owned arrays using R’s ALTREP
(Alternative Representations) framework. Instead of copying data between
Julia and R, jlview returns lightweight R vectors that point directly
into Julia’s memory.

|                        | Latency | R Memory         |
|------------------------|---------|------------------|
| **jlview (zero-copy)** | 38 ms   | 0 MB             |
| **copy (collect)**     | 2.7 s   | 9.3 GB           |
| **Improvement**        | **72×** | **100% savings** |

*Benchmark: 50K × 25K Float64 matrix (9.3 GB)*

## Installation

``` r
# install.packages("remotes")
remotes::install_github("tanaylab/jlview")
```

### Requirements

- R ≥ 4.0
- [Julia](https://julialang.org/) ≥ 1.6
- [JuliaCall](https://github.com/JuliaInterop/JuliaCall) R package

## Usage

``` r
library(jlview)
JuliaCall::julia_setup()

# Create a Julia array
JuliaCall::julia_command("x = randn(10000, 1000)")

# Zero-copy view — R sees Julia's memory directly
m <- jlview(JuliaCall::julia_eval("x"))
dim(m) # [1] 10000  1000
sum(m) # works natively, no data copied

# Named arrays are supported
JuliaCall::julia_command("using NamedArrays")
JuliaCall::julia_command("named = NamedArray(randn(3), [\"a\", \"b\", \"c\"])")
v <- jlview_named_vector(JuliaCall::julia_eval("named"))
v["a"] # access by name, still zero-copy

# Sparse matrices (zero-copy values, shifted indices)
JuliaCall::julia_command("using SparseArrays")
JuliaCall::julia_command("sp = sprand(1000, 500, 0.01)")
s <- jlview_sparse(JuliaCall::julia_eval("sp"))
class(s) # "dgCMatrix"

# Explicit release to free Julia memory early
jlview_release(m)
```

## Key Features

- **Zero-copy dense arrays** — Float64, Int32 map directly to R’s
  REALSXP, INTSXP
- **Type conversion** — Float32, Int64, Int16 are converted once in
  Julia, then zero-copy to R
- **Named arrays** — NamedArray row/column names attached atomically
  without triggering copy
- **Sparse matrices** — `dgCMatrix` with zero-copy values (`nzval`) and
  shifted indices
- **Copy-on-write** — R’s standard COW semantics: reads are zero-copy,
  writes trigger materialization
- **GC safety** — Julia arrays are pinned while R holds references;
  three-layer defense (pinning dict, memory pressure tracking, explicit
  release)
- **Fork safety** — Safe with
  [`parallel::mclapply()`](https://rdrr.io/r/parallel/mclapply.html)
  (PID-guarded finalizers)
- **Serialization** —
  [`saveRDS()`](https://rdrr.io/r/base/readRDS.html)/[`readRDS()`](https://rdrr.io/r/base/readRDS.html)
  work correctly (materializes on save)

## Supported Types

| Julia type       | R type      | Method                           |
|------------------|-------------|----------------------------------|
| `Array{Float64}` | `numeric`   | Direct zero-copy                 |
| `Array{Int32}`   | `integer`   | Direct zero-copy                 |
| `Array{Float32}` | `numeric`   | Convert in Julia, then zero-copy |
| `Array{Int64}`   | `numeric`   | Convert in Julia, then zero-copy |
| `Array{Int16}`   | `integer`   | Convert in Julia, then zero-copy |
| `Array{UInt8}`   | `raw`       | ALTREP RAWSXP zero-copy          |
| `Array{Bool}`    | `logical`   | Copy (layout incompatible)       |
| `String[]`       | `character` | Copy (layout incompatible)       |

## How It Works

jlview uses R’s
[ALTREP](https://svn.r-project.org/R/branches/ALTREP/ALTREP.html)
framework to create R vectors backed by Julia memory:

1.  **Pin** — The Julia array is stored in a global dictionary,
    preventing Julia’s GC from collecting it
2.  **Wrap** — An ALTREP R vector is created whose `Dataptr` returns
    Julia’s raw data pointer
3.  **Use** — R operations (sum, subsetting, etc.) read directly from
    Julia’s memory
4.  **Release** — When R garbage-collects the ALTREP object, a C
    finalizer calls Julia to unpin the array

The entire pin→ALTREP→finalizer path is implemented in C using Julia’s C
API (`jl_call1`), avoiding JuliaCall overhead and ensuring safety during
R’s garbage collection.
