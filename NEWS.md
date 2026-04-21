# jlview 0.1.1

## Test infrastructure

* Skip the full test suite on CRAN (tests now run only when `NOT_CRAN=true`,
  which is set by `devtools::test()` and by CI). This avoids flaky behaviour
  on CRAN Windows builders where Julia's runtime state and installed Julia
  packages are not under our control.
* Gracefully skip `NamedArrays`-dependent tests when the `NamedArrays` Julia
  package is not installed, instead of erroring.

# jlview 0.1.0

Initial release.

## Features

* Zero-copy R views of Julia Float64 and Int32 arrays via ALTREP
* Automatic type conversion for Float32, Int64, Int16, and UInt8 arrays
* Sparse matrix support (dgCMatrix) with zero-copy nonzero values
* Named vector and matrix support with atomic dimnames (no COW)
* Scope-based release with `with_jlview()`
* ALTREP Sum/Min/Max methods calling Julia directly for performance
* GC pressure tracking with configurable threshold
* Safe cross-runtime garbage collection via C-level finalizers
* Fork safety (mclapply), Julia shutdown safety, double-release protection
* Full serialization support (saveRDS/readRDS)
