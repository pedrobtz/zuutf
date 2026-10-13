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

read_fixture <- function(name) {
  path <- test_path("fixtures", name)
  readBin(path, "raw", file.size(path))
}

# iconv()'s name for each of zuutf's.
iconv_name <- c(
  "UTF-8" = "UTF-8", "UTF-16LE" = "UTF-16LE", "UTF-16BE" = "UTF-16BE",
  "UTF-32LE" = "UTF-32LE", "UTF-32BE" = "UTF-32BE", "Latin-1" = "latin1"
)

# iconv() of a list of raw vectors, NULL where it fails.
iconv_raw <- function(x, from, to) {
  iconv(x, iconv_name[[from]], iconv_name[[to]], toRaw = TRUE)
}

# The test texts as raw vectors in `enc`, from UTF-8 strings.
encode_all <- function(texts, enc) {
  lapply(texts, function(t) iconv(enc2utf8(t), "UTF-8", iconv_name[[enc]], toRaw = TRUE)[[1L]])
}

conversion_texts <- function(n = 200) {
  sample <- rawToChar(read_fixture("sample.utf8.txt"))
  Encoding(sample) <- "UTF-8"
  lines <- strsplit(sample, "\n", fixed = TRUE)[[1L]]
  random <- vapply(seq_len(n), function(i) {
    intToUtf8(random_code_points(sample(0:120, 1)))
  }, "")
  c("", "a", lines, sample, random)
}

conversion_encodings <- c("UTF-8", "UTF-16LE", "UTF-16BE", "UTF-32LE", "UTF-32BE", "Latin-1")
