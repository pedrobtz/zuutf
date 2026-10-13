test_that("encoding and decoding round-trip under every alphabet and padding", {
  withr::local_seed(20261013)
  lengths <- c(0:20, sample(21:600, 10000 - 21, TRUE))
  inputs <- lapply(lengths, function(n) as.raw(sample(0:255, n, TRUE)))
  for (url in c(FALSE, TRUE)) {
    for (pad in c(FALSE, TRUE)) {
      for (x in inputs) {
        s <- base64_encode(x, url = url, pad = pad)
        if (!identical(base64_decode(s, url = url), x)) {
          fail(sprintf("url = %s, pad = %s, length %d", url, pad, length(x)))
        }
      }
      succeed()
    }
  }
  # strict decoding takes what padded encoding writes
  for (x in inputs[1:500]) {
    expect_identical(base64_decode(base64_encode(x), forgiving = FALSE), x)
  }
})

test_that("RFC 4648 section 10 vectors encode and decode", {
  v <- read_tsv_fixture("rfc4648-base64.tsv")
  v$binary[is.na(v$binary)] <- ""
  for (i in seq_len(nrow(v))) {
    expect_identical(base64_encode(v$binary[[i]]), v$base64[[i]])
    expect_identical(rawToChar(base64_decode(v$base64[[i]], forgiving = FALSE)),
                     v$binary[[i]])
    expect_identical(base64_encode(charToRaw(v$binary[[i]]), pad = FALSE),
                     sub("=+$", "", v$base64[[i]]))
  }
})

test_that("every WHATWG forgiving-base64 vector decodes or fails as specified", {
  v <- read_tsv_fixture("whatwg-base64.tsv")
  expect_identical(nrow(v), 80L)
  for (i in seq_len(nrow(v))) {
    input <- hex_raw(v$input_hex[[i]])
    if (is.null(input)) input <- raw()
    expected <- hex_raw(v$output_hex[[i]])
    got <- tryCatch(base64_decode(input), zuutf_base64_error = function(e) NULL)
    expect_identical(got, expected, info = v$input_hex[[i]])
  }
  for_each_kernel({
    for (i in seq_len(nrow(v))) {
      input <- hex_raw(v$input_hex[[i]])
      if (is.null(input)) input <- raw()
      got <- tryCatch(base64_decode(input), zuutf_base64_error = function(e) NULL)
      expect_identical(got, hex_raw(v$output_hex[[i]]), info = kernel)
    }
  })
})

test_that("strict decoding rejects whitespace, missing padding and extra bits", {
  offset_of <- function(s) {
    tryCatch(base64_decode(s, forgiving = FALSE),
             zuutf_base64_error = function(e) e$offset)
  }
  expect_identical(offset_of("aGVs bG8="), 5L)          # whitespace
  expect_identical(offset_of("aGVsbG8=\n"), 9L)
  expect_identical(offset_of("\taGVsbG8="), 1L)
  expect_identical(offset_of("aGVsbG8"), 7L)            # no padding
  expect_identical(offset_of("aGVsbA"), 6L)
  expect_identical(offset_of("aGVsbG9="), 7L)           # non-zero trailing bits
  expect_identical(offset_of("aGVsbB=="), 6L)
  expect_identical(offset_of("aGVsb"), 5L)              # one character left over
  expect_identical(offset_of("aGVs*G8="), 5L)           # not in the alphabet
  expect_identical(offset_of("aGVsbG8=="), 8L)          # too much padding: from its start
  # forgiving decoding takes the first four of these
  expect_identical(rawToChar(base64_decode("aGVs bG8=")), "hello")
  expect_identical(rawToChar(base64_decode("aGVsbG8")), "hello")
  expect_identical(rawToChar(base64_decode("aGVsbG9=")), "hello")
  expect_error(base64_decode("aGVsb"), class = "zuutf_base64_error")
})

test_that("every byte value in every position of a short input", {
  for (n in 1:6) {
    for (pos in seq_len(n)) {
      for (b in 0:255) {
        x <- as.raw(rep(0x41, n))
        x[pos] <- as.raw(b)
        for (url in c(FALSE, TRUE)) {
          s <- base64_encode(x, url = url)
          if (!identical(base64_decode(s, url = url, forgiving = FALSE), x)) {
            fail(sprintf("n = %d, pos = %d, byte %d, url = %s", n, pos, b, url))
          }
        }
      }
    }
  }
  succeed()
})

test_that("line_length matches base64enc's lines joined with line feeds", {
  skip_if_not_installed("base64enc")
  withr::local_seed(20261013)
  inputs <- c(list(raw(), as.raw(1:57), as.raw(0:99)),
              lapply(c(1, 45, 48, 300, 1000), function(n) as.raw(sample(0:255, n, TRUE))))
  for (x in inputs) {
    for (w in c(4, 8, 64, 76)) {
      expected <- paste(base64enc::base64encode(x, linewidth = w), collapse = "\n")
      expect_identical(base64_encode(x, line_length = w), expected,
                       info = paste(length(x), w))
    }
    if (length(x)) {                     # base64enc gives character(0) for raw()
      expect_identical(base64_encode(x), base64enc::base64encode(x))
    }
  }
})

test_that("the alphabets are kept apart unless url = NA", {
  std <- "+/8="
  web <- "-_8="
  expect_identical(base64_decode(std), as.raw(c(0xfb, 0xff)))
  expect_identical(base64_decode(web, url = TRUE), as.raw(c(0xfb, 0xff)))
  expect_error(base64_decode(web), class = "zuutf_base64_error")
  expect_error(base64_decode(std, url = TRUE), class = "zuutf_base64_error")
  expect_identical(base64_decode(std, url = NA), as.raw(c(0xfb, 0xff)))
  expect_identical(base64_decode(web, url = NA), as.raw(c(0xfb, 0xff)))
  expect_identical(base64_decode("+_8=", url = NA), as.raw(c(0xfb, 0xff)))
  expect_identical(base64_encode(as.raw(c(0xfb, 0xff)), url = TRUE), "-_8=")
  expect_identical(base64_encode(as.raw(c(0xfb, 0xff)), url = TRUE, pad = FALSE), "-_8")
})

test_that("arguments are checked", {
  expect_identical(base64_encode(raw()), "")
  expect_identical(base64_decode(""), raw())
  expect_identical(base64_encode("h\u00e9"), base64_encode(charToRaw(enc2utf8("h\u00e9"))))
  expect_error(base64_encode(c("a", "b")), class = "zuutf_invalid_argument")
  expect_error(base64_encode(NA_character_), class = "zuutf_invalid_argument")
  expect_error(base64_encode(list(raw())), class = "zuutf_invalid_argument")
  expect_error(base64_encode(raw(), url = NA), class = "zuutf_invalid_argument")
  expect_error(base64_encode(raw(), pad = "yes"), class = "zuutf_invalid_argument")
  expect_error(base64_encode(raw(), line_length = 0), class = "zuutf_invalid_argument")
  expect_error(base64_encode(raw(), line_length = 2.5), class = "zuutf_invalid_argument")
  expect_error(base64_decode(1), class = "zuutf_invalid_argument")
  expect_error(base64_decode("", url = "x"), class = "zuutf_invalid_argument")
  expect_error(base64_decode("", forgiving = NA), class = "zuutf_invalid_argument")
  b <- "\xff"
  Encoding(b) <- "bytes"
  expect_error(base64_encode(b), class = "zuutf_invalid_argument")
})
