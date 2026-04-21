# Skip all tests on CRAN or if Julia is not available.
#
# Julia's runtime state on CRAN build machines is not under our control
# (Julia may be absent, present at an unexpected path, or have a different
# set of Julia packages installed). We therefore gate the full test suite
# on NOT_CRAN=true, which is set by devtools::test() and by this package's
# CI. Tests skip cleanly on CRAN while still running locally and in CI.
JULIA_AVAILABLE <- FALSE
JL_NAMED_ARRAYS_AVAILABLE <- FALSE

if (identical(Sys.getenv("NOT_CRAN"), "true")) {
    tryCatch(
        {
            JuliaCall::julia_setup()
            # jlview_ensure_init() is called lazily, but force it here for tests
            jlview:::jlview_ensure_init()
            JULIA_AVAILABLE <<- TRUE

            # Probe for optional Julia packages used by a subset of tests.
            JL_NAMED_ARRAYS_AVAILABLE <<- tryCatch(
                {
                    JuliaCall::julia_command("using NamedArrays")
                    TRUE
                },
                error = function(e) FALSE
            )
        },
        error = function(e) {
            JULIA_AVAILABLE <<- FALSE
        }
    )
}
