## Test environments

* macOS (GitHub Actions), R release
* Ubuntu (GitHub Actions), R release and devel (R CMD check only, tests skipped
  due to upstream JuliaCall/RCall signal handler conflict on Linux)
* Local: RHEL 8, R 4.3.3, Julia 1.11

## R CMD check results

0 errors | 0 warnings | 1 note

* NOTE: Package has a SystemRequirements field (Julia >= 1.6). Tests are
  skipped when Julia is not available (`skip_if(!JULIA_AVAILABLE)`).

## Downstream dependencies

* dafr (tanaylab/dafr) — R adapter for DataAxesFormats.jl, uses jlview for
  zero-copy array transfer
