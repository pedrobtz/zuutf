# zuutf.h: every member "may be called from any thread" (issue #85, for
# zugodb's worker threads). src/threads.c calls them from several threads
# at once and compares each result with a single-threaded run.

expect_clean <- function(r, threads) {
  expect_identical(r$threads, as.integer(threads))
  expect_gt(r$calls, 0)
  expect_identical(r$mismatched, 0)
  expect_identical(r$unstable, 0)
  expect_identical(r$overruns, 0)
  expect_identical(r$failed, 0)
  expect_identical(r$kernel_differs, 0)
}

test_that("threads agree with one thread, on shared and different buffers", {
  inputs <- thread_inputs()
  for (n in c(2L, 8L, 32L)) {
    expect_clean(api_threads(inputs, threads = n, rounds = 10L), n)
  }
})

test_that("the threads' results are the R functions' results", {
  inputs <- thread_inputs()
  api_threads(inputs, threads = 4L, rounds = 2L)
  for (x in inputs) {
    expected_ok <- is.na(zuutf::utf_error_at(x))
    expect_identical(api_validate(x, "utf8")[[1]] == 0, expected_ok)
  }
})

# The table's first call in a process makes simdutf pick its kernel. Here
# that first call is made by 16 threads together.
test_that("threads making the process's first calls agree", {
  out <- tempfile(fileext = ".rds")
  code <- sprintf(
    "library(zuutftest); saveRDS(api_threads(thread_inputs(), 16L, 5L), %s)",
    deparse(out)
  )
  rscript <- file.path(R.home("bin"), "Rscript")
  status <- system2(rscript, c("-e", shQuote(code)), stdout = FALSE, stderr = FALSE)
  expect_identical(status, 0L)
  expect_clean(readRDS(out), 16L)
})
