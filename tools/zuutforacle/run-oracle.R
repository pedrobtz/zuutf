# Run the oracle's tests against the installed packages under the kernel
# SIMDUTF_FORCE_IMPLEMENTATION names, from tools/zuutforacle/tests/testthat.
# A file rather than Rscript -e: Windows' Rscript crashes on a multi-line -e.
stopifnot(zuutf::zuutf_info()$kernel == Sys.getenv("SIMDUTF_FORCE_IMPLEMENTATION"))
library(zuutforacle)
res <- as.data.frame(testthat::test_dir(".", package = "zuutforacle",
  load_package = "installed", stop_on_failure = FALSE, reporter = "location"))
cat(sprintf("%d expectations, %d failed, %d skipped\n",
  sum(res$nb), sum(res$failed), sum(res$skipped)))
if (sum(res$nb) == 0L || sum(res$failed) > 0L || any(res$error)) stop("oracle failed")
