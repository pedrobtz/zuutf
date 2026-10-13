test_that("utf_valid() agrees with validUTF8() on the UTF-8 stress test", {
  lines <- kuhn_lines()
  # a line holding U+0000 is valid UTF-8, but no R string can hold it
  nul <- vapply(lines, function(b) any(b == as.raw(0)), logical(1))
  expect_true(all(utf_valid(lines[nul])))
  lines <- lines[!nul]
  expected <- vapply(lines, function(b) validUTF8(rawToChar(b)), logical(1))
  # the file is mostly valid and has a few dozen malformed lines
  expect_gt(sum(!expected), 20L)
  expect_gt(sum(expected), 100L)
  expect_identical(utf_valid(lines), expected)
  expect_identical(utf_valid(vapply(lines, utf8_string, "")), expected)
  for_each_kernel(expect_identical(utf_valid(lines), expected, info = kernel))
})

test_that("utf_valid() agrees with validUTF8() on 10,000 random byte strings", {
  withr::local_seed(20261013)
  # bytes 1 to 255: a string cannot hold NUL, so validUTF8() cannot judge it
  random <- lapply(sample(0:200, sweep(10000, cran = 2000), TRUE), function(n) {
    as.raw(sample(1:255, n, TRUE))
  })
  # and valid text with one byte changed, so both outcomes are common
  mutated <- lapply(seq_len(sweep(2000, cran = 500)), function(i) {
    b <- charToRaw(intToUtf8(random_code_points(sample(1:50, 1))))
    b[sample(length(b), 1)] <- as.raw(sample(1:255, 1))
    b
  })
  inputs <- c(random, mutated)
  expected <- vapply(inputs, function(b) validUTF8(rawToChar(b)), logical(1))
  expect_identical(utf_valid(inputs), expected)
})

test_that("every malformed UTF-8 class is invalid at its first byte", {
  cases <- list(
    overlong_2 = bytes(0x61, 0xc0, 0xaf),
    overlong_3 = bytes(0x61, 0xe0, 0x80, 0xaf),
    overlong_4 = bytes(0x61, 0xf0, 0x80, 0x80, 0xaf),
    surrogate_high = bytes(0x61, 0xed, 0xa0, 0x80),
    surrogate_low = bytes(0x61, 0xed, 0xbf, 0xbf),
    above_10ffff = bytes(0x61, 0xf4, 0x90, 0x80, 0x80),
    f5_lead = bytes(0x61, 0xf5, 0x80, 0x80, 0x80),
    truncated_2 = bytes(0x61, 0xc3),
    truncated_3 = bytes(0x61, 0xe2, 0x82),
    truncated_4 = bytes(0x61, 0xf0, 0x9f, 0x98),
    lone_continuation = bytes(0x61, 0x80),
    ff = bytes(0x61, 0xff)
  )
  for (name in names(cases)) {
    b <- cases[[name]]
    expect_false(utf_valid(b), info = name)
    expect_false(validUTF8(rawToChar(b)), info = name)
    expect_identical(utf_error_at(b), 2L, info = name)
  }
})

test_that("utf_error_at() gives the first error's offset in bytes", {
  expect_identical(utf_error_at(charToRaw("abc")), NA_integer_)
  expect_identical(utf_error_at(bytes(0xff)), 1L)
  expect_identical(utf_error_at(bytes(0x61, 0x62, 0x63, 0xc3, 0x28)), 4L)
  expect_identical(utf_error_at(c(charToRaw("caf\u00e9"), bytes(0xff))), 6L)
  # two errors: the first counts
  expect_identical(utf_error_at(bytes(0x61, 0xff, 0x62, 0xff)), 2L)
  # past a 64-byte block
  b <- c(charToRaw(strrep("a", 100)), bytes(0xe2, 0x82))
  expect_identical(utf_error_at(b), 101L)
  for_each_kernel(expect_identical(utf_error_at(b), 101L, info = kernel))
})

test_that("a matching byte-order mark is skipped and offsets start after it", {
  b <- c(bom[["UTF-8"]], charToRaw("ab"), bytes(0xff))
  expect_false(utf_valid(b))
  expect_identical(utf_error_at(b), 3L)
  expect_identical(utf_count(c(bom[["UTF-8"]], charToRaw("ab"))), 2L)

  le <- c(bom[["UTF-16LE"]], utf16le("ab"), bytes(0x00, 0xdc))
  expect_identical(utf_error_at(le, "UTF-16LE"), 3L)
  be <- c(bom[["UTF-32BE"]], utf32be("ab"), bytes(0x00, 0x11, 0x00, 0x00))
  expect_identical(utf_error_at(be, "UTF-32BE"), 3L)
})

test_that("UTF-16 is checked in either byte order", {
  text <- "a\u00e9\u4e2d\U0001f600"
  expect_true(utf_valid(utf16le(text), "UTF-16LE"))
  expect_true(utf_valid(utf16be(text), "UTF-16BE"))
  # a lone high surrogate, a lone low surrogate, a reversed pair
  lone_high <- c(utf16le("a"), bytes(0x3d, 0xd8), utf16le("b"))
  lone_low <- c(utf16le("a"), bytes(0x00, 0xde))
  reversed <- c(bytes(0x00, 0xde, 0x3d, 0xd8))
  expect_identical(utf_error_at(lone_high, "UTF-16LE"), 2L)
  expect_identical(utf_error_at(lone_low, "UTF-16LE"), 2L)
  expect_identical(utf_error_at(reversed, "UTF-16LE"), 1L)
  # an odd byte is a partial unit
  expect_identical(utf_error_at(c(utf16le("ab"), bytes(0x61)), "UTF-16LE"), 3L)
})

test_that("UTF-32 is checked in either byte order", {
  text <- "a\u00e9\u4e2d\U0001f600"
  expect_true(utf_valid(utf32le(text), "UTF-32LE"))
  expect_true(utf_valid(utf32be(text), "UTF-32BE"))
  above <- c(utf32le("a"), bytes(0x00, 0x00, 0x11, 0x00))
  surrogate <- c(utf32be("ab"), bytes(0x00, 0x00, 0xd8, 0x00))
  expect_identical(utf_error_at(above, "UTF-32LE"), 2L)
  expect_identical(utf_error_at(surrogate, "UTF-32BE"), 3L)
  # the swap path: big-endian input read as little-endian is out of range
  expect_false(utf_valid(utf32be("a"), "UTF-32LE"))
  expect_identical(utf_error_at(c(utf32le("a"), bytes(0x62, 0x00)), "UTF-32LE"), 2L)
})

test_that("\"UTF-16\" and \"UTF-32\" take the byte order from the BOM", {
  text <- "a\u00e9\U0001f600"
  expect_true(utf_valid(c(bom[["UTF-16LE"]], utf16le(text)), "UTF-16"))
  expect_true(utf_valid(c(bom[["UTF-16BE"]], utf16be(text)), "UTF-16"))
  expect_true(utf_valid(utf16be(text), "UTF-16"))          # no BOM: BE
  expect_true(utf_valid(c(bom[["UTF-32LE"]], utf32le(text)), "UTF-32"))
  expect_true(utf_valid(utf32be(text), "UTF-32"))
  expect_false(utf_valid(utf32le(text), "UTF-32"))         # LE read as BE
  expect_identical(utf_count(c(bom[["UTF-16LE"]], utf16le(text)), "UTF-16"), 3L)
})

test_that("Latin-1 is always valid and ASCII stops at 0x80", {
  expect_true(utf_valid(as.raw(0:255), "Latin-1"))
  expect_identical(utf_error_at(as.raw(0:255), "Latin-1"), NA_integer_)
  expect_identical(utf_error_at(as.raw(0:255), "ASCII"), 129L)
  expect_identical(utf_is_ascii(list(as.raw(0:127), as.raw(0:128))), c(TRUE, FALSE))
})

test_that("the three input shapes and NA give one result per element", {
  ok <- charToRaw("ok")
  bad <- bytes(0xc0)
  expect_identical(utf_valid(ok), TRUE)
  expect_identical(utf_valid(list(ok, bad, NULL)), c(TRUE, FALSE, NA))
  expect_identical(utf_valid(list(a = ok, b = bad)), c(a = TRUE, b = FALSE))
  s <- c(x = "ok", y = NA, z = utf8_string(bad))
  expect_identical(utf_valid(s), c(x = TRUE, y = NA, z = FALSE))
  expect_identical(utf_error_at(s), c(x = NA, y = NA, z = 1L))
  expect_identical(utf_valid(character()), logical())
  expect_identical(utf_valid(list()), logical())
  expect_identical(utf_valid(raw()), TRUE)
})

test_that("character input is taken in its marked encoding", {
  latin1 <- "caf\xe9"
  Encoding(latin1) <- "latin1"
  expect_true(utf_valid(latin1))                    # converted to UTF-8 first
  expect_identical(utf_count(latin1), 4L)
  invalid <- utf8_string(bytes(0x61, 0xff))
  expect_false(utf_valid(invalid))
  b <- "\xff"
  Encoding(b) <- "bytes"
  expect_error(utf_valid(b), class = "zuutf_invalid_argument")
  expect_false(utf_valid(b, useBytes = TRUE))
  expect_true(utf_valid(b, "Latin-1", useBytes = TRUE))
  expect_error(utf_valid("a", "UTF-16LE"), class = "zuutf_invalid_argument")
  # useBytes reads the bytes of any string, in any encoding
  s <- utf8_string(utf16le("\u4e2d\u6587"))
  expect_true(utf_valid(s, "UTF-16LE", useBytes = TRUE))
})

test_that("every encoding name is matched without regard to case or hyphens", {
  text <- "a\u00e9"
  inputs <- list(
    "UTF-8" = charToRaw(enc2utf8(text)), "utf8" = charToRaw(enc2utf8(text)),
    "UTF-16LE" = utf16le(text), "utf16le" = utf16le(text),
    "UTF-16BE" = utf16be(text), "Utf-16be" = utf16be(text),
    "UTF-16" = utf16be(text), "utf16" = utf16be(text),
    "UTF-32LE" = utf32le(text), "utf32le" = utf32le(text),
    "UTF-32BE" = utf32be(text), "UTF32BE" = utf32be(text),
    "UTF-32" = utf32be(text), "utf-32" = utf32be(text),
    "Latin-1" = bytes(0x61, 0xe9), "latin1" = bytes(0x61, 0xe9),
    "ASCII" = charToRaw("ab"), "ascii" = charToRaw("ab")
  )
  for (name in names(inputs)) {
    expect_true(utf_valid(inputs[[name]], name), info = name)
    expect_identical(utf_error_at(inputs[[name]], name), NA_integer_, info = name)
    expect_identical(utf_count(inputs[[name]], name), 2L, info = name)
  }
  expect_error(utf_valid(raw(), "UTF-7"), class = "zuutf_invalid_argument")
  expect_error(utf_valid(raw(), c("UTF-8", "ASCII")), class = "zuutf_invalid_argument")
})

test_that("arguments of the wrong type are refused", {
  expect_error(utf_valid(1:3), class = "zuutf_invalid_argument")
  expect_error(utf_valid(list(raw(), "a")), class = "zuutf_invalid_argument")
  expect_error(utf_valid(factor("a")), class = "zuutf_invalid_argument")
  expect_error(utf_valid("a", useBytes = NA), class = "zuutf_invalid_argument")
  expect_error(utf_is_ascii(1), class = "zuutf_invalid_argument")
  expect_error(utf_valid(1), class = "zuutf_error")
})

test_that("every function takes all three shapes in every encoding", {
  text <- "\u4e2d\u6587"   # no zero byte in UTF-8 or UTF-16, so a string holds it
  good <- list(
    "UTF-8" = charToRaw(enc2utf8(text)), "UTF-16LE" = utf16le(text),
    "UTF-16BE" = utf16be(text), "UTF-16" = c(bom[["UTF-16LE"]], utf16le(text)),
    "UTF-32LE" = utf32le(text), "UTF-32BE" = utf32be(text),
    "UTF-32" = c(bom[["UTF-32LE"]], utf32le(text)),
    "Latin-1" = bytes(0x61, 0xe9), "ASCII" = charToRaw("ab")
  )
  bad <- list(
    "UTF-8" = bytes(0x61, 0xff), "UTF-16LE" = bytes(0x61, 0x00, 0x00, 0xdc),
    "UTF-16BE" = bytes(0x00, 0x61, 0xdc, 0x00),
    "UTF-16" = bytes(0x00, 0x61, 0xdc, 0x00),
    "UTF-32LE" = bytes(0x61, 0, 0, 0, 0, 0, 0x11, 0),
    "UTF-32BE" = bytes(0, 0, 0, 0x61, 0, 0x11, 0, 0),
    "UTF-32" = bytes(0, 0, 0, 0x61, 0, 0x11, 0, 0),
    "Latin-1" = NULL,                 # nothing is invalid Latin-1
    "ASCII" = bytes(0x61, 0x80)
  )
  for (enc in names(good)) {
    g <- good[[enc]]
    b <- bad[[enc]]
    shapes <- list(g, b, NULL)        # b NULL for Latin-1: then NA too
    second <- if (is.null(b)) NA else FALSE

    expect_true(utf_valid(g, enc), info = enc)
    expect_identical(utf_valid(shapes, enc), c(TRUE, second, NA), info = enc)
    expect_identical(utf_error_at(g, enc), NA_integer_, info = enc)
    expect_identical(is.na(utf_error_at(shapes, enc)),
                     c(TRUE, is.null(b), TRUE), info = enc)
    expect_identical(utf_count(g, enc), 2L, info = enc)
    expect_identical(utf_count(shapes, enc), c(2L, NA, NA), info = enc)
    if (enc != "ASCII") {
      to <- if (enc == "UTF-8") "UTF-16LE" else "UTF-8"
      expect_false(is.na(utf_length_as(g, enc, to)), info = enc)
      expect_identical(is.na(utf_length_as(shapes, enc, to)),
                       c(FALSE, TRUE, TRUE), info = enc)
    }
    # character input: UTF-32 always has zero bytes, which no R string holds
    if (!any(g == as.raw(0))) {
      s <- utf8_string(g)
      expect_true(utf_valid(s, enc, useBytes = TRUE), info = enc)
      expect_identical(utf_error_at(s, enc, useBytes = TRUE), NA_integer_, info = enc)
      expect_identical(utf_count(s, enc, useBytes = TRUE), 2L, info = enc)
    }
  }
  expect_identical(utf_is_ascii(bytes(0x61)), TRUE)
  expect_identical(utf_is_ascii(list(bytes(0x61), bytes(0xe9), NULL)), c(TRUE, FALSE, NA))
  expect_identical(utf_is_ascii(c("a", NA, "\u00e9")), c(TRUE, NA, FALSE))
  expect_identical(utf_length_as(c("a", NA), to = "UTF-32LE"), c(4L, NA))
  expect_identical(utf_length_as(charToRaw("a"), to = "UTF-32LE"), 4L)
})
