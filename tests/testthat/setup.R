# Skip all tests if Julia is not available
tryCatch(
    {
        JuliaCall::julia_setup()
        # jlview_ensure_init() is called lazily, but force it here for tests
        jlview:::jlview_ensure_init()
        JULIA_AVAILABLE <- TRUE
    },
    error = function(e) {
        JULIA_AVAILABLE <<- FALSE
    }
)
