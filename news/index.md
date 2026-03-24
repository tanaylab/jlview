# Changelog

## jlview 0.1.0

CRAN release: 2026-03-23

Initial release.

### Features

- Zero-copy R views of Julia Float64 and Int32 arrays via ALTREP
- Automatic type conversion for Float32, Int64, Int16, and UInt8 arrays
- Sparse matrix support (dgCMatrix) with zero-copy nonzero values
- Named vector and matrix support with atomic dimnames (no COW)
- Scope-based release with
  [`with_jlview()`](https://tanaylab.github.io/jlview/reference/with_jlview.md)
- ALTREP Sum/Min/Max methods calling Julia directly for performance
- GC pressure tracking with configurable threshold
- Safe cross-runtime garbage collection via C-level finalizers
- Fork safety (mclapply), Julia shutdown safety, double-release
  protection
- Full serialization support (saveRDS/readRDS)
