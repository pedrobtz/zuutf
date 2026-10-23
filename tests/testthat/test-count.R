test_that("utf_count() agrees with nchar() on valid text", {
  withr::local_seed(20261013)
  texts <- vapply(
    1:500,
    function(i) {
      intToUtf8(random_code_points(sample(0:300, 1)))
    },
    ""
  )
  expected <- nchar(texts, type = "chars")
  expect_identical(utf_count(texts), expected)
  expect_identical(utf_count(lapply(texts, charToRaw)), expected)
  expect_identical(utf_count(lapply(texts, utf16le), "UTF-16LE"), expected)
  expect_identical(utf_count(lapply(texts, utf16be), "UTF-16BE"), expected)
  expect_identical(utf_count(lapply(texts, utf32le), "UTF-32LE"), expected)
  expect_identical(utf_count(lapply(texts, utf32be), "UTF-32BE"), expected)
  for_each_kernel(
    expect_identical(
      utf_count(lapply(texts, utf16le), "UTF-16LE"),
      expected,
      info = kernel
    )
  )
})

test_that("utf_count() is NA where the element is invalid or missing", {
  expect_identical(
    utf_count(list(charToRaw("ab"), bytes(0xff), NULL)),
    c(2L, NA, NA)
  )
  expect_identical(utf_count(c(a = "x", b = NA)), c(a = 1L, b = NA))
  expect_identical(utf_count(bytes(0x61, 0xe9), "Latin-1"), 2L)
  expect_identical(utf_count(bytes(0x61, 0xe9), "ASCII"), NA_integer_)
  # a character vector is UTF-8 text, which "ASCII" can count too
  expect_identical(utf_count(c(a = "abc", b = NA), "ascii"), c(a = 3L, b = NA))
  expect_identical(utf_count("caf\u00e9", "ASCII"), NA_integer_)
})

test_that("utf_length_as() puts U+FFFF in one UTF-16 unit and U+10000 in two", {
  # random code points almost never land on the boundary
  edge <- list(
    "UTF-32LE" = bytes(0xff, 0xff, 0, 0, 0, 0, 0x01, 0),
    "UTF-32BE" = bytes(0, 0, 0xff, 0xff, 0, 0x01, 0, 0)
  )
  for (from in names(edge)) {
    x <- edge[[from]]
    expect_identical(utf_length_as(x, from, "UTF-16LE"), 6L, info = from)
    expect_identical(utf_length_as(x, from, "UTF-16BE"), 6L, info = from)
    expect_identical(utf_length_as(x, from, "UTF-8"), 7L, info = from)
    expect_identical(
      length(utf_convert(x, from, "UTF-16LE")),
      6L,
      info = from
    )
  }
})

test_that("utf_length_as() gives the bytes a conversion produces", {
  withr::local_seed(20261013)
  texts <- c(
    "",
    "abc",
    "caf\u00e9",
    "\u4e2d\u6587",
    "\U0001f600",
    vapply(
      1:200,
      function(i) intToUtf8(random_code_points(sample(0:100, 1))),
      ""
    )
  )
  encoders <- list(
    "UTF-8" = function(t) charToRaw(enc2utf8(t)),
    "UTF-16LE" = utf16le,
    "UTF-16BE" = utf16be,
    "UTF-32LE" = utf32le,
    "UTF-32BE" = utf32be
  )
  targets <- c("UTF-8", "UTF-16LE", "UTF-16BE", "UTF-32LE", "UTF-32BE")
  for (from in names(encoders)) {
    input <- lapply(texts, encoders[[from]])
    for (to in targets) {
      expected <- vapply(
        texts,
        function(t) length(encoders[[to]](t)),
        1L,
        USE.NAMES = FALSE
      )
      expect_identical(
        utf_length_as(input, from, to),
        expected,
        info = paste(from, "->", to)
      )
    }
    expect_identical(
      utf_length_as(input, from, "Latin-1"),
      nchar(texts, type = "chars"),
      info = paste(from, "-> Latin-1")
    )
  }
})

test_that("utf_length_as() reads Latin-1 and the BOM-chosen orders", {
  latin1 <- as.raw(c(0x41, 0xe9, 0xff))
  expect_identical(utf_length_as(latin1, "Latin-1", "UTF-8"), 5L)
  expect_identical(utf_length_as(latin1, "Latin-1", "UTF-16LE"), 6L)
  expect_identical(utf_length_as(latin1, "Latin-1", "UTF-32BE"), 12L)
  expect_identical(utf_length_as(latin1, "Latin-1", "Latin-1"), 3L)
  le <- c(boms()[["UTF-16LE"]], utf16le("\U0001f600"))
  expect_identical(utf_length_as(le, "UTF-16", "UTF-8"), 4L)
  expect_identical(utf_length_as("\u00e9", to = "UTF-16BE"), 2L)
})

test_that("utf_length_as() is NA for invalid input and checks its names", {
  expect_identical(
    utf_length_as(list(bytes(0xff), NULL), "UTF-8", "UTF-16LE"),
    c(NA_integer_, NA_integer_)
  )
  expect_error(utf_length_as("a"), class = "zuutf_invalid_argument")
  expect_error(
    utf_length_as("a", to = "UTF-16"),
    class = "zuutf_invalid_argument"
  )
  expect_error(
    utf_length_as("a", to = "ASCII"),
    class = "zuutf_invalid_argument"
  )
  expect_error(
    utf_length_as(raw(), "ASCII", "UTF-8"),
    class = "zuutf_invalid_argument"
  )
  expect_error(
    utf_length_as("a", "UTF-16LE", "UTF-8"),
    class = "zuutf_invalid_argument"
  )
})
