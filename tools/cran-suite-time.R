# Design §10 and roadmap Stage 6: the test suite CRAN runs (NOT_CRAN unset)
# takes under 15 seconds. Run from the package root against the installed
# package; fails above the limit.
Sys.unsetenv("NOT_CRAN")
library(zuutf)
t <- system.time(
  res <- as.data.frame(testthat::test_dir(
    "tests/testthat",
    package = "zuutf",
    load_package = "installed",
    reporter = "silent",
    stop_on_failure = FALSE
  ))
)[["elapsed"]]
cat(sprintf(
  "CRAN suite: %.1f s, %d expectations, %d failed, %d skipped\n",
  t,
  sum(res$nb),
  sum(res$failed),
  sum(res$skipped)
))
summary <- Sys.getenv("GITHUB_STEP_SUMMARY")
if (nzchar(summary)) {
  cat(
    sprintf(
      "### CRAN suite\n\n%.1f s for %d expectations (limit 15 s)\n",
      t,
      sum(res$nb)
    ),
    file = summary,
    append = TRUE
  )
}
if (sum(res$failed) > 0L || any(res$error)) {
  stop("the CRAN suite failed")
}
if (t >= 15) {
  stop(sprintf("the CRAN suite took %.1f s, over 15 s", t))
}
