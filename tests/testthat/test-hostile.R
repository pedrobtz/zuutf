# Hostile input (design §10): the SIMD kernels work in 64-byte blocks, so
# errors are planted at every position of inputs of every length from 0 to
# 200 bytes and around 4096, on every kernel this processor supports, and
# the answers are checked against base R or a direct computation. In the
# CRAN suite they run on the kernel in use, since the kernel-matrix job runs
# the whole suite once per kernel; ZUUTF_SLOW_TESTS runs them on every
# kernel in-process too.

test_that("a bad byte at every position of every length is found there", {
  lengths <- if (slow_tests()) c(0:200, 4090:4100) else sweep(c(0:130, 4094:4098), cran = c(0:70, 4095:4097))
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
  on_kernels({
    for (seq in list(as.raw(c(0xc3, 0xa9)), as.raw(c(0xe2, 0x82, 0xac)),
                     as.raw(c(0xf0, 0x9f, 0x98, 0x80)))) {
      for (n in c(1:70, 125:130, 4090:4100)) {
        for (cut in seq_len(length(seq) - 1L)) {
          b <- c(as.raw(rep(0x61, n)), seq[seq_len(cut)])
          expect_identical(utf_error_at(b), as.integer(n + 1L), info = paste(kernel, n, cut))
          # and followed by ASCII, so the error is not at the end
          expect_identical(utf_error_at(c(b, charToRaw("z"))), as.integer(n + 1L))
        }
      }
    }
  })
})

test_that("multi-byte text of every length decodes as base R decodes it", {
  withr::local_seed(20261013)
  cps <- random_code_points(4200)
  on_kernels({
    for (n in sweep(c(0:200, 4090:4100), cran = c(0:100, 4095:4097))) {
      text <- intToUtf8(cps[seq_len(n)])
      b <- charToRaw(text)
      expect_identical(utf_count(b), n, info = paste(kernel, n))
      expect_identical(utf_decode(utf_convert(b, "UTF-8", "UTF-16LE"), "UTF-16LE"), text)
      expect_identical(utf_convert(utf_convert(b, "UTF-8", "UTF-32BE"), "UTF-32BE", "UTF-8"), b)
    }
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
  for (n in if (slow_tests()) 1:200 else c(1:20, 63:66)) {
    for (i in seq_len(n)) {
      b <- as.raw(rep(0x61, n))
      b[i] <- as.raw(0)
      expect_identical(utf_convert(b, "UTF-8", "UTF-8"), b)
      e <- tryCatch(utf_decode(b, "UTF-8"), zuutf_nul_error = function(e) e$offset)
      if (!identical(e, i)) fail(sprintf("length %d, NUL at %d: offset %s", n, i, format(e)))
    }
  }
  succeed()
})
