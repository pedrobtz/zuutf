test_that("conversions match iconv() byte for byte wherever iconv() succeeds", {
  withr::local_seed(20261013)
  texts <- conversion_texts()
  # iconv() cannot succeed into Latin-1 beyond U+00FF, and on a list of raw
  # vectors it returns the input unchanged rather than NULL when it fails,
  # so a Latin-1 side takes only the texts Latin-1 holds
  narrow <- texts[vapply(
    texts,
    function(t) all(utf8ToInt(t) <= 255L),
    logical(1)
  )]
  narrow <- c(
    narrow,
    "caf\u00e9",
    "\u00a1Hola!",
    intToUtf8(1:255, multiple = FALSE)
  )
  for (from in conversion_encodings()) {
    for (to in conversion_encodings()) {
      t <- if ("Latin-1" %in% c(from, to)) narrow else texts
      input <- encode_all(t, from)
      expected <- iconv_raw(input, from, to)
      expect_identical(
        utf_convert(input, from, to),
        expected,
        info = paste(from, "->", to)
      )
    }
  }
})

test_that("every fixture converts as iconv() converts it", {
  files <- c(
    "UTF-8" = "sample.utf8.txt",
    "UTF-16LE" = "sample.utf16le.txt",
    "UTF-16BE" = "sample.utf16be.txt",
    "UTF-32LE" = "sample.utf32le.txt",
    "UTF-32BE" = "sample.utf32be.txt"
  )
  # the sample text is beyond Latin-1, so only the Unicode targets
  for (from in names(files)) {
    x <- read_fixture(files[[from]])
    for (to in names(files)) {
      expect_identical(
        utf_convert(x, from, to),
        iconv_raw(list(x), from, to)[[1L]],
        info = paste(files[[from]], "->", to)
      )
    }
  }
  # and every valid line of the stress test, NUL line aside
  lines <- kuhn_lines()
  lines <- lines[
    utf_valid(lines) &
      !vapply(lines, function(b) any(b == as.raw(0)), logical(1))
  ]
  for (to in c("UTF-16LE", "UTF-16BE", "UTF-32LE", "UTF-32BE")) {
    expect_identical(
      utf_convert(lines, "UTF-8", to),
      iconv_raw(lines, "UTF-8", to),
      info = to
    )
  }
})

test_that("the fixtures in every encoding decode to the sample text", {
  text <- rawToChar(read_fixture("sample.utf8.txt"))
  Encoding(text) <- "UTF-8"
  for (f in c("utf16le", "utf16be", "utf32le", "utf32be")) {
    enc <- toupper(sub("^utf(16|32)(le|be)$", "UTF-\\1\\2", f))
    plain <- read_fixture(paste0("sample.", f, ".txt"))
    with_bom <- read_fixture(paste0("sample.", f, "-bom.txt"))
    expect_identical(utf_decode(plain, enc), text, info = f)
    expect_identical(utf_decode(with_bom, enc), text, info = f) # BOM dropped
    expect_identical(utf_decode(with_bom), text, info = f) # BOM decides
    expect_identical(
      utf_decode(with_bom, sub("(LE|BE)$", "", enc)),
      text,
      info = f
    )
    expect_identical(
      utf_convert(with_bom, enc, "UTF-8"),
      read_fixture("sample.utf8.txt")
    )
    expect_identical(utf_encode(text, enc), plain, info = f) # no BOM written
  }
  # without a BOM, "UTF-16" and "UTF-32" are big-endian
  expect_identical(
    utf_decode(read_fixture("sample.utf16be.txt"), "UTF-16"),
    text
  )
  expect_identical(
    utf_decode(read_fixture("sample.utf32be.txt"), "UTF-32"),
    text
  )
  for_each_kernel(
    expect_identical(
      utf_decode(read_fixture("sample.utf16le-bom.txt")),
      text,
      info = kernel
    )
  )
})

test_that("every pair round-trips", {
  withr::local_seed(20261013)
  texts <- conversion_texts(100)
  narrow <- c("", "caf\u00e9", intToUtf8(1:255, multiple = FALSE))
  for (a in conversion_encodings()) {
    for (b in conversion_encodings()) {
      t <- if ("Latin-1" %in% c(a, b)) narrow else texts
      x <- encode_all(t, a)
      expect_identical(
        utf_convert(utf_convert(x, a, b), b, a),
        x,
        info = paste(a, b)
      )
    }
  }
})

test_that("the three policies act on ill-formed input in every source encoding", {
  # one ill-formed unit after "a", then "b", in each source encoding
  cases <- list(
    "UTF-8" = list(bytes = bytes(0x61, 0xff, 0x62), offset = 2L),
    "UTF-16LE" = list(bytes = bytes(0x61, 0, 0x00, 0xdc, 0x62, 0), offset = 2L),
    "UTF-16BE" = list(bytes = bytes(0, 0x61, 0xdc, 0x00, 0, 0x62), offset = 2L),
    "UTF-32LE" = list(
      bytes = bytes(0x61, 0, 0, 0, 0, 0, 0x11, 0, 0x62, 0, 0, 0),
      offset = 2L
    ),
    "UTF-32BE" = list(
      bytes = bytes(0, 0, 0, 0x61, 0, 0x11, 0, 0, 0, 0, 0, 0x62),
      offset = 2L
    )
  )
  for (from in names(cases)) {
    b <- cases[[from]]$bytes
    ok <- encode_all("ok", from)[[1L]]
    e <- tryCatch(utf_convert(list(ok, b), from, "UTF-8"), error = identity)
    expect_s3_class(e, "zuutf_encoding_error")
    expect_identical(e$index, 2L, info = from)
    expect_identical(e$offset, cases[[from]]$offset, info = from)
    expect_identical(e$encoding, from, info = from)
    expect_error(utf_decode(b, from), class = "zuutf_encoding_error")

    expect_identical(
      utf_decode(b, from, invalid = "replace"),
      "a\ufffdb",
      info = from
    )
    expect_identical(
      utf_convert(b, from, "UTF-16LE", invalid = "replace"),
      utf16le("a\ufffdb"),
      info = from
    )
    expect_identical(
      utf_convert(b, from, "Latin-1", invalid = "replace"),
      charToRaw("a?b"),
      info = from
    )
    # every other target writes U+FFFD in its own encoding and byte order
    for (to in setdiff(conversion_encodings(), "Latin-1")) {
      expect_identical(
        utf_convert(b, from, to, invalid = "replace"),
        encode_all("a\ufffdb", to)[[1L]],
        info = paste(from, to)
      )
    }

    expect_identical(
      utf_decode(list(b, NULL), from, invalid = "na"),
      c(NA_character_, NA_character_),
      info = from
    )
    expect_null(utf_convert(b, from, "UTF-8", invalid = "na"))
    expect_identical(
      utf_convert(list(x = b), from, "UTF-8", invalid = "na"),
      list(x = NULL),
      info = from
    )
  }
  # Latin-1 has no ill-formed input; a partial trailing unit is one error
  expect_identical(
    utf_decode(bytes(0x61, 0, 0x62), "UTF-16LE", invalid = "replace"),
    "a\ufffd"
  )
  expect_identical(
    tryCatch(
      utf_decode(bytes(0x61, 0, 0, 0, 0x62), "UTF-32LE"),
      zuutf_encoding_error = function(e) e$offset
    ),
    2L
  )
})

test_that("code points a Latin-1 target cannot hold follow the policy", {
  x <- utf16le("a\u4e2db\U0001f600c")
  e <- tryCatch(utf_convert(x, "UTF-16LE", "Latin-1"), error = identity)
  expect_s3_class(e, "zuutf_encoding_error")
  expect_identical(e$offset, 2L)
  expect_identical(e$encoding, "Latin-1")
  expect_identical(
    utf_convert(x, "UTF-16LE", "Latin-1", invalid = "replace"),
    charToRaw("a?b?c")
  )
  expect_null(utf_convert(x, "UTF-16LE", "Latin-1", invalid = "na"))
  for (from in c("UTF-8", "UTF-16BE", "UTF-32LE", "UTF-32BE")) {
    input <- encode_all("a\u4e2db\U0001f600c", from)[[1L]]
    expect_identical(
      utf_convert(input, from, "Latin-1", invalid = "replace"),
      charToRaw("a?b?c"),
      info = from
    )
  }
  expect_identical(
    utf_encode("caf\u00e9\u20ac", "Latin-1", invalid = "replace"),
    bytes(0x63, 0x61, 0x66, 0xe9, 0x3f)
  )
})

test_that("the Latin-1 target's edge is between U+00FF and U+0100", {
  # the first-wide detectors of every source encoding, at their boundary
  offset <- c(
    "UTF-8" = 3L,
    "UTF-16LE" = 2L,
    "UTF-16BE" = 2L,
    "UTF-32LE" = 2L,
    "UTF-32BE" = 2L
  )
  for (from in names(offset)) {
    edge <- encode_all("\u00ff\u0100", from)[[1L]]
    expect_identical(
      utf_convert(edge, from, "Latin-1", invalid = "replace"),
      bytes(0xff, 0x3f),
      info = from
    )
    e <- tryCatch(utf_convert(edge, from, "Latin-1"), error = identity)
    expect_s3_class(e, "zuutf_encoding_error")
    expect_identical(e$offset, offset[[from]], info = from)
    expect_identical(
      utf_convert(encode_all("\u00ff", from)[[1L]], from, "Latin-1"),
      bytes(0xff),
      info = from
    )
  }
})

test_that("the replacement loop agrees with simdutf's on UTF-16", {
  withr::local_seed(20261013)
  texts <- conversion_texts(100)
  # break about one unit in twenty with a lone surrogate
  inputs <- lapply(texts, function(t) {
    b <- utf16le(t)
    n <- length(b) %/% 2L
    if (n > 0L) {
      at <- sample(n, max(1L, n %/% 20L))
      for (i in at) {
        b[2L * i - c(1L, 0L)] <- bytes(0x00, sample(c(0xd8, 0xdc), 1))
      }
    }
    b
  })
  lone <- list(
    bytes(0x00, 0xd8),
    bytes(0x00, 0xdc),
    bytes(0x00, 0xdc, 0x00, 0xd8),
    bytes(0x3d, 0xd8, 0x3d, 0xd8, 0x00, 0xde)
  )
  # both paths against known answers, so they cannot agree on a wrong one
  fffd <- "\ufffd"
  known <- c(fffd, fffd, strrep(fffd, 2), paste0(fffd, "\U0001f600"))
  for (simdutf in c(TRUE, FALSE)) {
    got <- zuutf:::run_convert(
      lone,
      "UTF-16LE",
      "UTF-8",
      "replace",
      1L,
      simdutf_replacement = simdutf
    )
    expect_identical(got, known, info = simdutf)
  }
  inputs <- c(inputs, lone)
  for (from in c("UTF-16LE", "UTF-16BE")) {
    x <- inputs
    if (from == "UTF-16BE") {
      x <- lapply(inputs, function(b) {
        if (length(b)) {
          b[c(rbind(seq(2, length(b), 2), seq(1, length(b), 2)))]
        } else {
          b
        }
      })
    }
    simdutf <- zuutf:::run_convert(x, from, "UTF-8", "replace", 0L)
    loop <- zuutf:::run_convert(
      x,
      from,
      "UTF-8",
      "replace",
      0L,
      simdutf_replacement = FALSE
    )
    expect_identical(loop, simdutf, info = from)
    expect_true(all(utf_valid(loop)))
  }
})

test_that("UTF-8 replacement follows the WHATWG decoder on the stress test", {
  input <- read_fixture("UTF-8-test.txt")
  expected <- read_fixture("UTF-8-test.whatwg.txt")
  # to raw, since the stress test holds a U+0000 no R string can
  expect_identical(
    utf_convert(input, "UTF-8", "UTF-8", invalid = "replace"),
    expected
  )
  for_each_kernel(
    expect_identical(
      utf_convert(input, "UTF-8", "UTF-8", invalid = "replace"),
      expected,
      info = kernel
    )
  )
  # Unicode's own example (Unicode 16.0, Table 3-8)
  b <- bytes(
    0x61,
    0xf1,
    0x80,
    0x80,
    0xe1,
    0x80,
    0xc2,
    0x62,
    0x80,
    0x63,
    0x80,
    0xbf,
    0x64
  )
  expect_identical(
    utf_decode(b, "UTF-8", invalid = "replace"),
    "a\ufffd\ufffd\ufffdb\ufffdc\ufffd\ufffdd"
  )
})

test_that("U+0000 raises zuutf_nul_error under every policy", {
  for (from in c(
    "UTF-8",
    "UTF-16LE",
    "UTF-16BE",
    "UTF-32LE",
    "UTF-32BE",
    "Latin-1"
  )) {
    x <- c(encode_all("ab", from)[[1L]], encode_all("c", from)[[1L]])
    unit <- length(encode_all("a", from)[[1L]])
    x <- append(x, raw(unit), after = 2L * unit) # "ab", U+0000, "c"
    for (policy in c("error", "replace", "na")) {
      ok <- encode_all("ok", from)[[1L]]
      e <- tryCatch(
        utf_decode(list(ok, x), from, invalid = policy),
        error = identity
      )
      expect_s3_class(e, "zuutf_nul_error")
      expect_identical(e$index, 2L, info = paste(from, policy))
      expect_identical(e$offset, 3L, info = paste(from, policy))
    }
    # utf_convert() keeps it
    expect_identical(utf_convert(x, from, from), x, info = from)
  }
  # an earlier ill-formed sequence wins under "error"; "na" drops the element
  b <- bytes(0xff, 0x00)
  expect_error(utf_decode(b, "UTF-8"), class = "zuutf_encoding_error")
  expect_identical(utf_decode(b, "UTF-8", invalid = "na"), NA_character_)
  expect_error(
    utf_decode(bytes(0x00, 0xff), "UTF-8"),
    class = "zuutf_nul_error"
  )
  # under "na" an ill-formed element is NA, a NUL before the error or not
  expect_identical(
    utf_decode(bytes(0x00, 0xff), "UTF-8", invalid = "na"),
    NA_character_
  )
})

test_that("utf_detect() puts a BOM alone, then the order of design \u00a76", {
  expect_identical(utf_detect(c(boms()[["UTF-8"]], charToRaw("a"))), "UTF-8")
  expect_identical(
    utf_detect(c(boms()[["UTF-16LE"]], utf16le("ab"))),
    "UTF-16LE"
  )
  expect_identical(
    utf_detect(c(boms()[["UTF-16BE"]], utf16be("ab"))),
    "UTF-16BE"
  )
  expect_identical(
    utf_detect(c(boms()[["UTF-32LE"]], utf32le("ab"))),
    "UTF-32LE"
  )
  expect_identical(
    utf_detect(c(boms()[["UTF-32BE"]], utf32be("ab"))),
    "UTF-32BE"
  )
  expect_identical(utf_detect(charToRaw("abc")), "UTF-8")
  expect_identical(
    utf_detect(charToRaw("abcd")),
    c("UTF-8", "UTF-16LE", "UTF-16BE")
  )
  # NULs and ASCII are valid UTF-8 too, which is why UTF-8 comes first
  expect_identical(
    utf_detect(utf32be("ab")),
    c("UTF-8", "UTF-16LE", "UTF-16BE", "UTF-32BE")
  )
  expect_identical(
    utf_detect(raw()),
    c("UTF-8", "UTF-16LE", "UTF-16BE", "UTF-32LE", "UTF-32BE")
  )
  expect_identical(utf_detect(bytes(0xff, 0xff, 0xff)), character())
  expect_identical(
    utf_detect(utf16le("\u4e2d\u6587\u5b57")),
    c("UTF-16LE", "UTF-16BE")
  )
  expect_identical(utf_detect(utf16le("\u00d8")), "UTF-16LE") # D8 00: a lone surrogate as BE
  for (f in c("utf16le", "utf16be", "utf32le", "utf32be")) {
    bomfile <- read_fixture(paste0("sample.", f, "-bom.txt"))
    expect_length(utf_detect(bomfile), 1L)
    expect_true(
      toupper(sub("^utf(16|32)", "UTF-\\1", f)) %in%
        utf_detect(read_fixture(paste0("sample.", f, ".txt"))),
      info = f
    )
  }
  expect_identical(
    utf_detect(list(a = charToRaw("abc"), b = NULL)),
    list(a = "UTF-8", b = NULL)
  )
  # "auto" with no candidate falls back to UTF-8 and its policy
  expect_identical(
    utf_decode(bytes(0x61, 0xff, 0xff), invalid = "replace"),
    "a\ufffd\ufffd"
  )
})

test_that("shapes, names and arguments", {
  expect_type(utf_convert(charToRaw("a"), "UTF-8", "UTF-16LE"), "raw")
  out <- utf_convert(list(p = charToRaw("a"), q = NULL), "UTF-8", "UTF-16LE")
  expect_identical(out, list(p = bytes(0x61, 0), q = NULL))
  expect_type(utf_encode("a"), "raw")
  expect_identical(
    utf_encode(c(x = "a", y = NA)),
    list(x = bytes(0x61, 0), y = NULL)
  )
  expect_null(utf_encode(NA_character_))
  expect_null(utf_encode("\u4e2d", "Latin-1", invalid = "na"))
  expect_identical(utf_encode(c(a = "x")), bytes(0x78, 0))
  expect_identical(utf_decode(list(a = charToRaw("x"))), c(a = "x"))
  expect_identical(Encoding(utf_decode(charToRaw("caf\u00e9"))), "UTF-8")
  expect_identical(utf_decode(raw()), "")
  latin1 <- "caf\xe9"
  Encoding(latin1) <- "latin1"
  expect_identical(
    utf_encode(latin1, "UTF-8"),
    charToRaw(enc2utf8("caf\u00e9"))
  )
  b <- "\xff" # R ignores a "bytes" mark on ASCII
  Encoding(b) <- "bytes"
  expect_error(utf_encode(b), class = "zuutf_invalid_argument")
  expect_error(
    utf_convert("a", "UTF-8", "UTF-16LE"),
    class = "zuutf_invalid_argument"
  )
  expect_error(utf_convert(raw(), "UTF-8"), class = "zuutf_invalid_argument")
  expect_error(
    utf_convert(raw(), "UTF-8", "UTF-16"),
    class = "zuutf_invalid_argument"
  )
  expect_error(
    utf_convert(raw(), "ASCII", "UTF-8"),
    class = "zuutf_invalid_argument"
  )
  expect_error(
    utf_decode(raw(), invalid = "drop"),
    class = "zuutf_invalid_argument"
  )
  expect_error(utf_decode("a"), class = "zuutf_invalid_argument")
  expect_error(utf_encode(1), class = "zuutf_invalid_argument")
  expect_error(utf_detect("a"), class = "zuutf_invalid_argument")
})
