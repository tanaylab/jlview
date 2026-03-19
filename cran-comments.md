## Test environments

* macOS (GitHub Actions), R release, Julia 1.11
* Ubuntu (GitHub Actions), R release and R-devel
* Local: RHEL 8, R 4.3.3, Julia 1.11
* R-hub: Linux (R-devel), Windows (R-devel), gcc-ASAN, clang-ASAN, clang-UBSAN, valgrind, LTO, rchk

## R CMD check results

0 errors | 0 warnings | 0 notes

## CRAN test information

Proper use of this package requires a Julia installation at runtime. This is
the same situation as 'diffeqr' and 'JuliaCall' on CRAN. All examples use
`\dontrun{}` and all tests are guarded with `skip_if(!JULIA_AVAILABLE)`, so
R CMD check passes without Julia. The full test suite (20 test files) runs on
GitHub Actions CI where Julia is installed. 

The package uses R's public ALTREP API (`R_ext/Altrep.h`) to create zero-copy
views of Julia-owned arrays, and resolves Julia C API symbols at runtime via
`dlsym()` (Unix) / `GetProcAddress()` (Windows) because libjulia is loaded
dynamically by JuliaCall. The compiled code never terminates the R process.

