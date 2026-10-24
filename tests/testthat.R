# testthat is in Suggests: CRAN's NOSUGGESTS flavour checks without it, so
# the suite runs only when it is installed.
if (requireNamespace("testthat", quietly = TRUE)) {
  library(testthat)
  library(zuutf)
  test_check("zuutf")
}
