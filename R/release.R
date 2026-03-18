#' Explicitly release a jlview object
#'
#' Unpins the Julia array immediately, freeing memory without waiting for
#' R's garbage collector. After release, accessing the data will error.
#'
#' @param x A jlview ALTREP vector
#' @return Invisible `NULL`
#' @export
jlview_release <- function(x) {
    jlview_ensure_init()
    if (!is_jlview(x)) {
        warning("jlview_release: not a jlview object, ignoring")
        return(invisible(NULL))
    }
    .Call("C_jlview_release", x, PACKAGE = "jlview")
    invisible(NULL)
}

#' Set the GC pressure threshold
#'
#' When total pinned bytes exceeds this threshold, jlview forces an R garbage
#' collection to reclaim stale ALTREP objects. Default is 2GB.
#'
#' @param bytes Threshold in bytes (numeric)
#' @return Invisible `NULL`
#' @export
jlview_set_gc_threshold <- function(bytes) {
    .Call("C_jlview_set_gc_threshold", as.double(bytes), PACKAGE = "jlview")
    invisible(NULL)
}

#' Get current GC pressure information
#'
#' Returns the current amount of Julia memory pinned by jlview objects
#' and the threshold at which forced GC is triggered.
#'
#' @return A list with `pinned_bytes` and `threshold`
#' @export
jlview_gc_pressure <- function() {
    .Call("C_jlview_gc_pressure", PACKAGE = "jlview")
}
