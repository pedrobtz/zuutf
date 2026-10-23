test_that("conditions carry the zuutf classes", {
  e <- tryCatch(utf_valid("a", "EBCDIC"), error = identity)
  expect_s3_class(
    e,
    c("zuutf_invalid_argument", "zuutf_error", "error", "condition")
  )
  e <- zuutf:::zuutf_condition(
    "zuutf_encoding_error",
    "m",
    index = 2L,
    offset = 5L,
    encoding = "UTF-8"
  )
  expect_s3_class(e, c("zuutf_encoding_error", "zuutf_error", "error"))
  expect_identical(e$index, 2L)
  expect_identical(e$offset, 5L)
  expect_identical(e$encoding, "UTF-8")
  expect_error(
    zuutf:::abort_internal_error("m"),
    class = "zuutf_internal_error"
  )
  expect_error(
    zuutf:::abort_encoding_error("m", 1L, 1L, "UTF-8"),
    class = "zuutf_encoding_error"
  )
})

test_that("a forced kernel the processor cannot run is an internal error", {
  # Run in a child process: the kernel is chosen once per process.
  skip_on_cran()
  skip_if_not(testthat::is_checking(), "needs the installed package")
  # The child reports "supported" when the forced kernel turns out to run
  # where it runs: under valgrind this process sees valgrind's emulated CPU
  # while the child runs on the real one.
  script <- withr::local_tempfile(fileext = ".R")
  writeLines(
    c(
      "k <- Sys.getenv('SIMDUTF_FORCE_IMPLEMENTATION')",
      "info <- zuutf::zuutf_info()",
      "if (k %in% info$kernels$name[info$kernels$supported]) cat('supported') else",
      "  cat(tryCatch(zuutf::utf_valid('a'), zuutf_internal_error = function(e) 'internal'))"
    ),
    script
  )
  rscript <- file.path(R.home("bin"), "Rscript")
  run_forced <- function(kernel) {
    # a script file, not -e: Windows' cmd does not keep single quotes, and
    # Rscript -e leaves a temporary file behind when the child fails;
    # R_TESTS is R CMD check's startup file for the test process only
    withr::with_envvar(
      c(SIMDUTF_FORCE_IMPLEMENTATION = kernel, R_TESTS = ""),
      suppressWarnings(system2(
        rscript,
        shQuote(script),
        stdout = TRUE,
        stderr = TRUE
      ))
    )
  }

  # an unknown name: simdutf's "unsupported" stub
  out <- run_forced("nope")
  expect_identical(out, "internal", info = paste(out, collapse = "\n"))

  # a compiled-in kernel this processor lacks: simdutf would run it anyway
  info <- zuutf_info()
  lacking <- info$kernels$name[!info$kernels$supported]
  skip_if(length(lacking) == 0L, "this processor runs every compiled-in kernel")
  out <- run_forced(lacking[[1L]])
  skip_if(identical(out, "supported"), "the child process can run the kernel")
  expect_identical(out, "internal", info = paste(out, collapse = "\n"))
})
