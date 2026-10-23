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

test_that("every C status maps to its condition class", {
  # kinds ZUT_TOO_LONG, ZUT_INTERNAL and ZUT_B64_* other than INVALID need
  # a 2 GB input or a simdutf fault, so the mapping is tested directly
  convert_status <- function(kind) {
    zuutf:::raise_status(c(kind, 2, 3, 1), "UTF-16LE", NULL)
  }
  expect_error(convert_status(1), class = "zuutf_encoding_error")
  expect_error(convert_status(2), class = "zuutf_encoding_error")
  expect_error(convert_status(3), class = "zuutf_nul_error")
  expect_error(convert_status(4), class = "zuutf_size_error")
  for (kind in c(5, 6, -1)) {
    expect_error(convert_status(kind), class = "zuutf_internal_error")
  }
  e <- tryCatch(convert_status(1), error = identity)
  expect_identical(e$index, 2L)
  expect_identical(e$offset, 3L)
  expect_identical(e$encoding, "UTF-8")
  e <- tryCatch(convert_status(2), error = identity)
  expect_identical(e$encoding, "UTF-16LE")

  base64_status <- function(kind) {
    zuutf:::run_base64(list(as.raw(1), c(kind, 4)), NULL)
  }
  expect_identical(base64_status(0), as.raw(1))
  expect_error(base64_status(1), class = "zuutf_base64_error")
  expect_identical(tryCatch(base64_status(1), error = identity)$offset, 4L)
  expect_error(base64_status(2), class = "zuutf_size_error")
  for (kind in c(3, 4, -1)) {
    expect_error(base64_status(kind), class = "zuutf_internal_error")
  }
})

test_that("a forced kernel the processor cannot run is an internal error", {
  # Run in a child process: the kernel is chosen once per process.
  skip_on_cran()
  skip_if_not(testthat::is_checking(), "needs the installed package")
  # The child reports "supported" when the forced kernel turns out to run
  # where it runs: under valgrind this process sees valgrind's emulated CPU
  # while the child runs on the real one.
  script <- withr::local_tempfile(fileext = ".R")
  # Every export that reaches simdutf is called once and prints one token,
  # so dropping check_kernel() from any of them shows here, not as SIGILL.
  writeLines(
    c(
      "k <- Sys.getenv('SIMDUTF_FORCE_IMPLEMENTATION')",
      "info <- zuutf::zuutf_info()",
      "if (k %in% info$kernels$name[info$kernels$supported]) {",
      "  cat('supported')",
      "} else {",
      "  b <- charToRaw('a')",
      "  calls <- list(",
      "    function() zuutf::utf_valid('a'),",
      "    function() zuutf::utf_error_at('a'),",
      "    function() zuutf::utf_is_ascii('a'),",
      "    function() zuutf::utf_count('a'),",
      "    function() zuutf::utf_length_as('a', to = 'UTF-16LE'),",
      "    function() zuutf::utf_convert(b, 'UTF-8', 'UTF-16LE'),",
      "    function() zuutf::utf_decode(b),",
      "    function() zuutf::utf_encode('a'),",
      "    function() zuutf::utf_detect(b),",
      "    function() zuutf::base64_encode(b),",
      "    function() zuutf::base64_decode('YQ==')",
      "  )",
      "  tokens <- vapply(calls, function(f) tryCatch({ f(); 'ran' },",
      "    zuutf_internal_error = function(e) 'internal'), '')",
      "  cat(unique(tokens), sep = ',')",
      "}"
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
