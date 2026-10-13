test_that("conditions carry the zuutf classes", {
  e <- tryCatch(utf_valid("a", "EBCDIC"), error = identity)
  expect_s3_class(e, c("zuutf_invalid_argument", "zuutf_error", "error", "condition"))
  e <- zuutf:::zuutf_condition("zuutf_encoding_error", "m",
                               index = 2L, offset = 5L, encoding = "UTF-8")
  expect_s3_class(e, c("zuutf_encoding_error", "zuutf_error", "error"))
  expect_identical(e$index, 2L)
  expect_identical(e$offset, 5L)
  expect_identical(e$encoding, "UTF-8")
  expect_error(zuutf:::abort_internal_error("m"), class = "zuutf_internal_error")
  expect_error(
    zuutf:::abort_encoding_error("m", 1L, 1L, "UTF-8"),
    class = "zuutf_encoding_error"
  )
})

test_that("a forced kernel the processor cannot run is an internal error", {
  # Run in a child process: the kernel is chosen once per process.
  skip_on_cran()
  skip_if_not(testthat::is_checking(), "needs the installed package")
  info <- zuutf_info()
  unsupported <- setdiff(c("icelake", "haswell", "westmere", "arm64", "nope"),
                         info$kernels$name[info$kernels$supported])[1L]
  rscript <- file.path(R.home("bin"), "Rscript")
  out <- withr::with_envvar(
    c(SIMDUTF_FORCE_IMPLEMENTATION = unsupported),
    system2(rscript, c("-e", shQuote(paste0(
      "cat(tryCatch(zuutf::utf_valid('a'), ",
      "zuutf_internal_error = function(e) 'internal'))"
    ))), stdout = TRUE)
  )
  expect_identical(out, "internal")
})
