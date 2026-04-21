## Resubmission

This is a patch release (0.1.1) that addresses the test failures reported by
CRAN on the Windows builders:

* `r-release-windows-x86_64` (FAIL): the testthat process hung for 20 minutes
  and was killed.
* `r-oldrel-windows-x86_64` (ERROR): five tests failed because the optional
  Julia package `NamedArrays` was not installed on the CRAN builder.

### Changes

* `tests/testthat/setup.R` now only initializes the Julia runtime when
  `NOT_CRAN=true`. This matches the convention used by `devtools::test()`
  and the package's CI. On CRAN, every test now skips cleanly without
  starting Julia, so the builder cannot hang or fail because of Julia-side
  issues.
* Tests that require the Julia `NamedArrays` package additionally skip
  when that package is not installed, instead of erroring.

Other packages on CRAN that wrap Julia (`JuliaCall`, `diffeqr`) follow the
same pattern of skipping Julia-dependent tests on CRAN. Full test coverage
continues to run on GitHub Actions CI with Julia 1.11 and the required Julia
packages installed.

## Test environments

* macOS (GitHub Actions), R release, Julia 1.11
* Ubuntu (GitHub Actions), R release and R-devel
* Local: RHEL 8, R 4.3.3, Julia 1.11

## R CMD check results

0 errors | 0 warnings | 0 notes

## CRAN test information

Proper use of this package requires a Julia installation at runtime. This is
the same situation as 'diffeqr' and 'JuliaCall' on CRAN. All examples use
`\dontrun{}` and all tests are guarded both by `skip_if(!JULIA_AVAILABLE)`
and by the `NOT_CRAN` gate in `tests/testthat/setup.R`, so R CMD check
passes without Julia. The full test suite (20 test files) runs on
GitHub Actions CI where Julia is installed.

The package uses R's public ALTREP API (`R_ext/Altrep.h`) to create zero-copy
views of Julia-owned arrays, and resolves Julia C API symbols at runtime via
`dlsym()` (Unix) / `GetProcAddress()` (Windows) because libjulia is loaded
dynamically by JuliaCall. The compiled code never terminates the R process.
