# Hostile input (design §10): the SIMD kernels work in 64-byte blocks, so
# errors are planted at every position of inputs of every length from 0 to
# 200 bytes and around 4096, on every kernel this processor supports, and
# the answers are checked against base R or a direct computation. In the
# CRAN suite they run on the kernel in use, since the kernel-matrix job runs
# the whole suite once per kernel; ZUUTF_SLOW_TESTS runs them on every
# kernel in-process too.

test_that("a bad byte at every position of every length is found there", {
  lengths <- if (slow_tests()) c(0:200, 4090:4100) else sweep_size(c(0:130, 4094:4098), cran = c(0:70, 4095:4097))
  on_kernels({
    for (n in lengths) {
      base <- as.raw(rep(0x61, n))
      expect_true(utf_valid(base), info = paste(kernel, n))
      positions <- if (n <= 200) seq_len(n) else c(1, 64, n %/% 2, n - 1, n)
      bad <- lapply(positions, function(i) { b <- base; b[i] <- as.raw(0xff); b })
      got <- utf_error_at(bad)
      if (!identical(got, as.integer(positions))) {
        fail(sprintf("%s: length %d, error offsets %s", kernel, n,
                     paste(head(got[got != positions]), collapse = " ")))
      }
    }
    succeed()
  })
})

test_that("a sequence truncated at every block boundary is found at its lead byte", {
  seqs <- list(as.raw(c(0xc3, 0xa9)), as.raw(c(0xe2, 0x82, 0xac)),
               as.raw(c(0xf0, 0x9f, 0x98, 0x80)))
  lengths <- sweep_size(c(1:70, 125:130, 4090:4100), cran = c(1:66, 127:129, 4095:4097))
  cases <- expand.grid(n = lengths, s = seq_along(seqs), cut = 1:3)
  cases <- cases[cases$cut < lengths(seqs)[cases$s], ]
  inputs <- Map(function(n, s, cut) c(as.raw(rep(0x61, n)), seqs[[s]][seq_len(cut)]),
                cases$n, cases$s, cases$cut)
  # and the same followed by ASCII, so the error is not at the end
  followed <- lapply(inputs, function(b) c(b, charToRaw("z")))
  on_kernels({
    expect_identical(utf_error_at(inputs), as.integer(cases$n + 1L), info = kernel)
    expect_identical(utf_error_at(followed), as.integer(cases$n + 1L), info = kernel)
  })
})

test_that("multi-byte text of every length decodes as base R decodes it", {
  withr::local_seed(20261013)
  cps <- random_code_points(4200)
  lengths <- sweep_size(c(0:200, 4090:4100), cran = c(0:100, 4095:4097))
  texts <- vapply(lengths, function(n) intToUtf8(cps[seq_len(n)]), "")
  utf8 <- lapply(texts, charToRaw)
  on_kernels({
    expect_identical(utf_count(utf8), lengths, info = kernel)
    expect_identical(utf_decode(utf_convert(utf8, "UTF-8", "UTF-16LE"), "UTF-16LE"), texts,
                     info = kernel)
    expect_identical(utf_convert(utf_convert(utf8, "UTF-8", "UTF-32BE"), "UTF-32BE", "UTF-8"),
                     utf8, info = kernel)
  })
})

test_that("a BOM alone, and a BOM cut short", {
  for (enc in names(bom)) {
    expect_identical(utf_decode(bom[[enc]], enc), "", info = enc)
    expect_identical(utf_convert(bom[[enc]], enc, "UTF-8"), raw(), info = enc)
    expect_identical(utf_count(bom[[enc]], enc), 0L, info = enc)
    expect_identical(utf_detect(bom[[enc]]), enc, info = enc)
  }
  expect_identical(utf_decode(bytes(0xef, 0xbb), "UTF-8", invalid = "replace"), "\ufffd")
  expect_identical(utf_decode(bytes(0xff), "UTF-16LE", invalid = "replace"), "\ufffd")
})

test_that("a NUL in every position is kept by utf_convert() and refused by utf_decode()", {
  lengths <- if (slow_tests()) 1:200 else sweep_size(c(1:20, 63:66), cran = c(1:8, 64:65))
  for (n in lengths) {
    inputs <- lapply(seq_len(n), function(i) { b <- as.raw(rep(0x61, n)); b[i] <- as.raw(0); b })
    expect_identical(utf_convert(inputs, "UTF-8", "UTF-8"), inputs)
    got <- vapply(inputs, function(b) {
      tryCatch(utf_decode(b, "UTF-8"), zuutf_nul_error = function(e) e$offset)
    }, integer(1))
    expect_identical(got, seq_len(n), info = paste("length", n))
  }
})
