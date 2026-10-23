# Every member of zuutf_api_v1, called through zuutf_api_get(), checked
# against zuutf's own R functions.

ERR_SUCCESS <- 0
ERR_SURROGATE <- 6
ERR_TOO_SMALL <- 10

text_bytes <- function() {
  charToRaw(enc2utf8(intToUtf8(c(0x61, 0xe9, 0x4e2d, 0x1f600))))
}

test_that("the table resolves and is at least as large as 0.1.0's", {
  size <- api_struct_size()
  expect_gt(size[[1]], 0)
  expect_identical(size[[1]], size[[2]])
  expect_identical(api_kernel(), zuutf::zuutf_info()$kernel)
})

test_that("validators match utf_error_at()", {
  good <- text_bytes()
  bad <- c(charToRaw("ab"), as.raw(0xff))
  expect_identical(api_validate(good, "utf8"), c(ERR_SUCCESS, length(good)))
  r <- api_validate(bad, "utf8")
  expect_gt(r[[1]], 0)
  expect_identical(r[[2]] + 1, as.numeric(zuutf::utf_error_at(bad)))
  le <- zuutf::utf_convert(good, "UTF-8", "UTF-16LE")
  expect_identical(api_validate(le, "utf16le"), c(ERR_SUCCESS, length(le) / 2))
  lone <- c(le, as.raw(c(0x00, 0xdc)))
  expect_identical(
    api_validate(lone, "utf16le"),
    c(ERR_SURROGATE, length(le) / 2)
  )
  native32 <- zuutf::utf_convert(
    good,
    "UTF-8",
    if (.Platform$endian == "little") "UTF-32LE" else "UTF-32BE"
  )
  expect_identical(
    api_validate(native32, "utf32"),
    c(ERR_SUCCESS, length(native32) / 4)
  )
  expect_true(api_validate(charToRaw("abc"), "ascii"))
  expect_false(api_validate(good, "ascii"))
  expect_identical(api_count_utf8(good), as.numeric(zuutf::utf_count(good)))
})

test_that("conversions match utf_convert(), and capacity is honoured", {
  good <- text_bytes()
  le <- zuutf::utf_convert(good, "UTF-8", "UTF-16LE")
  r <- api_convert(le, "utf16le_to_utf8")
  expect_identical(r[[1]], 0L)
  expect_identical(r[[3]], good)
  r <- api_convert(good, "utf8_to_utf16le")
  expect_identical(r[[3]], le)
  latin1 <- as.raw(c(0x63, 0x61, 0x66, 0xe9))
  r <- api_convert(latin1, "latin1_to_utf8")
  expect_identical(r[[3]], zuutf::utf_convert(latin1, "Latin-1", "UTF-8"))
  # one byte short: an error naming the capacity that is enough
  r <- api_convert(le, "utf16le_to_utf8", cap = length(good) - 1)
  expect_identical(r[[1]], as.integer(ERR_TOO_SMALL))
  expect_identical(r[[2]], as.numeric(length(good)))
  r <- api_convert(good, "utf8_to_utf16le", cap = length(le) / 2 - 1)
  expect_identical(r[[1]], as.integer(ERR_TOO_SMALL))
  # ill-formed input: the offset of the first error
  r <- api_convert(c(good, as.raw(0xff)), "utf8_to_utf16le")
  expect_gt(r[[1]], 0L)
  expect_identical(r[[2]], as.numeric(length(good)))
})

test_that("Base64 matches base64_encode() and base64_decode()", {
  withr_seed <- 20261013
  set.seed(withr_seed)
  x <- as.raw(sample(0:255, 1000, TRUE))
  for (flags in 0:3) {
    url <- bitwAnd(flags, 1L) != 0
    pad <- bitwAnd(flags, 2L) == 0
    r <- api_base64_encode(x, flags)
    expect_identical(r[[1]], 0L)
    s <- zuutf::base64_encode(x, url = url, pad = pad)
    expect_identical(rawToChar(r[[3]]), s)
    d <- api_base64_decode(charToRaw(s), if (url) 1L else 0L)
    expect_identical(d[[3]], x)
  }
  expect_identical(
    api_base64_decode(charToRaw("-_8="), 8L)[[3]],
    as.raw(c(0xfb, 0xff))
  )
  strict <- api_base64_decode(charToRaw("aGVs bG8="), 4L)
  expect_identical(strict[[1]], 7L) # whitespace is invalid when strict
  expect_identical(strict[[2]], 4)
  expect_identical(
    api_base64_decode(charToRaw("aGVs bG8="), 0L)[[3]],
    charToRaw("hello")
  )
  short <- api_base64_encode(x, 0L, cap = 10)
  expect_identical(short[[1]], as.integer(ERR_TOO_SMALL))
  short <- api_base64_decode(charToRaw("aGVsbG8="), 0L, cap = 2)
  expect_identical(short[[1]], as.integer(ERR_TOO_SMALL))
})
