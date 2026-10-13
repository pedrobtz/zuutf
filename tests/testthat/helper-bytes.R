# Byte strings for the tests, built from UTF-8 text with iconv(), which every
# platform's R can do, or from hex.

bytes <- function(...) as.raw(c(...))

# A UTF-8 string marked as such, so no locale conversion touches it.
utf8_string <- function(raw) {
  s <- rawToChar(raw)
  Encoding(s) <- "UTF-8"
  s
}

encode_as <- function(text, to) {
  iconv(enc2utf8(text), "UTF-8", to, toRaw = TRUE)[[1L]]
}

utf16le <- function(text) encode_as(text, "UTF-16LE")
utf16be <- function(text) encode_as(text, "UTF-16BE")
utf32le <- function(text) encode_as(text, "UTF-32LE")
utf32be <- function(text) encode_as(text, "UTF-32BE")

bom <- list(
  "UTF-8" = bytes(0xef, 0xbb, 0xbf),
  "UTF-16LE" = bytes(0xff, 0xfe),
  "UTF-16BE" = bytes(0xfe, 0xff),
  "UTF-32LE" = bytes(0xff, 0xfe, 0x00, 0x00),
  "UTF-32BE" = bytes(0x00, 0x00, 0xfe, 0xff)
)

# The UTF-8 stress test, one raw vector per line.
kuhn_lines <- function() {
  path <- test_path("fixtures", "UTF-8-test.txt")
  raw <- readBin(path, "raw", file.size(path))
  ends <- which(raw == as.raw(0x0a))
  starts <- c(1L, head(ends, -1L) + 1L)
  Map(function(a, b) raw[seq_len(b - a) + a - 1L], starts, ends)
}

# Random code points in every UTF-8 length class, surrogates excluded.
random_code_points <- function(n) {
  classes <- sample(1:4, n, replace = TRUE)
  cp <- integer(n)
  cp[classes == 1] <- sample(1:0x7f, sum(classes == 1), TRUE)
  cp[classes == 2] <- sample(0x80:0x7ff, sum(classes == 2), TRUE)
  cp[classes == 3] <- sample(c(0x800:0xd7ff, 0xe000:0xffff), sum(classes == 3), TRUE)
  cp[classes == 4] <- sample(0x10000:0x10ffff, sum(classes == 4), TRUE)
  cp
}
