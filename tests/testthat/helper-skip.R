# Test switches (alignment rule R7, design §10).
#
#   ZUUTF_SKIP_HEAVY=true    random sweeps shrink to what reaches every path;
#                            native-checks sets it for gctorture
#   ZUUTF_SLOW_TESTS=true    sweeps widen, and run on every kernel in-process
#   ZUUTF_TIMING_TESTS=true  assertions on elapsed time run
heavy_skipped <- function() identical(Sys.getenv("ZUUTF_SKIP_HEAVY"), "true")

# CRAN runs the suite without NOT_CRAN; every CI leg sets it.
on_cran <- function() !identical(Sys.getenv("NOT_CRAN"), "true")

# The size of a random sweep: `full` where NOT_CRAN is set (the size a
# roadmap exit criterion names, which CI shows), `cran` in CRAN's suite, to
# keep it under 15 seconds (design §10), and `heavy` under ZUUTF_SKIP_HEAVY.
sweep_size <- function(full, cran, heavy = cran) {
  if (heavy_skipped()) heavy else if (on_cran()) cran else full
}

slow_tests <- function() identical(Sys.getenv("ZUUTF_SLOW_TESTS"), "true")

skip_unless_timing <- function() {
  skip_if_not(identical(Sys.getenv("ZUUTF_TIMING_TESTS"), "true"), "ZUUTF_TIMING_TESTS is not true")
}

# Run code on every kernel under ZUUTF_SLOW_TESTS, else on the kernel in
# use: the kernel-matrix job already runs the whole suite once per kernel.
on_kernels <- function(code) {
  code <- substitute(code)
  env <- parent.frame()
  if (slow_tests()) {
    return(eval(substitute(for_each_kernel(code), list(code = code)), env))
  }
  eval(code, list(kernel = zuutf_info()$kernel), env)
  invisible()
}
