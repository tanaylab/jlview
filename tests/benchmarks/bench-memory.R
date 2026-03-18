# bench-memory.R — Memory and timing benchmarks for jlview zero-copy vs copy
#
# Usage:
#   source ~/miniconda3/etc/profile.d/conda.sh && conda activate dafr-mcview
#   cd /net/mraid20/ifs/wisdom/tanay_lab/tgdata/users/aviezerl/src/jlview
#   R -e "source('tests/benchmarks/bench-memory.R')"

cat("=== jlview Memory Benchmark ===\n\n")

# 1. Load the package via devtools
suppressMessages(devtools::load_all(export_all = FALSE))

# Manually load the shared library (NAMESPACE is missing useDynLib)
so_path <- file.path(getwd(), "src", "jlview.so")
if (file.exists(so_path) && !is.loaded("C_jlview_init_runtime", PACKAGE = "jlview")) {
    dyn.load(so_path)
}

# 2. Initialize Julia via JuliaCall
cat("Initializing Julia...\n")
suppressMessages(JuliaCall::julia_setup())

# Force jlview initialization by creating a tiny array
JuliaCall::julia_command("_warmup = Float64[1.0, 2.0, 3.0]")
warmup_arr <- JuliaCall::julia_eval("_warmup")
invisible(jlview(warmup_arr))
cat("Julia and jlview initialized.\n\n")

# 3. Define sizes
sizes <- c(1000L, 100000L, 1000000L, 10000000L)

# Results storage
results <- data.frame(
    size = integer(),
    copy_mb = numeric(),
    zerocopy_mb = numeric(),
    copy_ms = numeric(),
    zerocopy_ms = numeric(),
    stringsAsFactors = FALSE
)

# Helper: measure memory delta and timing
bench_one <- function(size, method = c("copy", "zerocopy")) {
    method <- match.arg(method)

    # Create a fresh Julia array
    cmd <- sprintf("_bench_arr = randn(Float64, %d)", size)
    JuliaCall::julia_command(cmd)
    jl_arr <- JuliaCall::julia_eval("_bench_arr")

    # Force full GC and record baseline
    gc(full = TRUE, reset = TRUE)
    mem_before <- gc(full = FALSE) # returns matrix with Ncells / Vcells used

    if (method == "copy") {
        timing <- system.time({
            r_obj <- JuliaCall::julia_call("collect", jl_arr, need_return = "R")
        })
    } else {
        timing <- system.time({
            r_obj <- jlview(jl_arr)
        })
    }

    # Force GC to get accurate used memory
    mem_after <- gc(full = FALSE)

    # Memory delta in MB (Vcells used, column "used" in MB)
    # gc() returns a matrix: rows = Ncells, Vcells; cols = used, gc trigger, max used
    # Column 2 is "Mb" for used memory
    mb_delta <- sum(mem_after[, 2]) - sum(mem_before[, 2])
    if (mb_delta < 0) mb_delta <- 0

    elapsed_ms <- timing[["elapsed"]] * 1000

    # Keep reference alive so GC doesn't reclaim during measurement
    force(r_obj)

    # Verify correctness: check length
    stopifnot(length(r_obj) == size)

    # Clean up
    rm(r_obj)
    gc(full = TRUE)
    JuliaCall::julia_command("_bench_arr = nothing")

    list(mb = mb_delta, ms = elapsed_ms)
}

# 4. Run benchmarks
cat(sprintf(
    "%-12s  %10s  %10s  %10s  %10s\n",
    "Size", "Copy MB", "ZC MB", "Copy ms", "ZC ms"
))
cat(paste(rep("-", 60), collapse = ""), "\n")

for (sz in sizes) {
    cat(sprintf("Benchmarking size = %d ...\n", sz))

    # Warm up for this size (one throwaway round)
    invisible(bench_one(sz, "copy"))
    invisible(bench_one(sz, "zerocopy"))

    # Actual measurement — average over 3 runs
    n_runs <- 3L
    copy_mb_acc <- 0
    copy_ms_acc <- 0
    zc_mb_acc <- 0
    zc_ms_acc <- 0

    for (i in seq_len(n_runs)) {
        res_copy <- bench_one(sz, "copy")
        copy_mb_acc <- copy_mb_acc + res_copy$mb
        copy_ms_acc <- copy_ms_acc + res_copy$ms

        res_zc <- bench_one(sz, "zerocopy")
        zc_mb_acc <- zc_mb_acc + res_zc$mb
        zc_ms_acc <- zc_ms_acc + res_zc$ms
    }

    row <- data.frame(
        size = sz,
        copy_mb = round(copy_mb_acc / n_runs, 3),
        zerocopy_mb = round(zc_mb_acc / n_runs, 3),
        copy_ms = round(copy_ms_acc / n_runs, 3),
        zerocopy_ms = round(zc_ms_acc / n_runs, 3)
    )

    cat(sprintf(
        "%-12d  %10.3f  %10.3f  %10.3f  %10.3f\n",
        row$size, row$copy_mb, row$zerocopy_mb,
        row$copy_ms, row$zerocopy_ms
    ))

    results <- rbind(results, row)
}

cat("\n=== Final Results ===\n")
print(results, row.names = FALSE)

# 5. Output JSON
cat("\n=== JSON Output ===\n")
json_rows <- apply(results, 1, function(r) {
    sprintf(
        '{"size": %d, "copy_mb": %.3f, "zerocopy_mb": %.3f, "copy_ms": %.3f, "zerocopy_ms": %.3f}',
        as.integer(r["size"]), r["copy_mb"], r["zerocopy_mb"],
        r["copy_ms"], r["zerocopy_ms"]
    )
})
cat(sprintf('{"results": [%s]}\n', paste(json_rows, collapse = ", ")))

cat("\nBenchmark complete.\n")
