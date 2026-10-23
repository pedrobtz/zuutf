# zufast against zuutf (design §10, D12, §14 criteria 2 and 3). ZUUTF_FIXTURES
# points at zuutf's tests/testthat/fixtures; hardening.yaml sets it.

fixtures <- function() {
  dir <- Sys.getenv("ZUUTF_FIXTURES")
  skip_if(!nzchar(dir) || !dir.exists(dir), "ZUUTF_FIXTURES is not set")
  dir
}

read_bytes <- function(path) readBin(path, "raw", file.size(path))

split_lines <- function(raw) {
  ends <- which(raw == as.raw(0x0a))
  starts <- c(1L, head(ends, -1L) + 1L)
  Map(function(a, b) raw[seq_len(b - a) + a - 1L], starts, ends)
}

# zuutf skips a leading byte-order mark (design §6) and zufast reads it as
# U+FEFF, so zufast is given the bytes after it
strip_utf8_bom <- function(b) {
  if (length(b) >= 3 && identical(b[1:3], as.raw(c(0xef, 0xbb, 0xbf)))) {
    b[-(1:3)]
  } else {
    b
  }
}

# unicode_lipsum's UTF-16 and UTF-32 files carry one more U+FEFF than its
# UTF-8 files (Emoji-Lipsum.utf16.txt starts ff fe ff fe), so the texts are
# compared without leading U+FEFF
drop_feff <- function(s) sub(paste0("^", intToUtf8(0xfeff), "+"), "", s)

expect_agree <- function(x, label) {
  z <- zufast_utf8(lapply(x, strip_utf8_bom))
  expect_identical(zuutf::utf_valid(x), z$valid, info = label)
  expect_identical(as.numeric(zuutf::utf_error_at(x)), z$offset, info = label)
  expect_identical(as.numeric(zuutf::utf_count(x)), z$count, info = label)
}

test_that("zufast and zuutf agree on every corpus file, whole and by line", {
  dir <- fixtures()
  files <- c(
    "UTF-8-test.txt",
    "UTF-8-test.whatwg.txt",
    "sample.utf8.txt",
    "sample.utf16le.txt",
    "sample.utf32be.txt"
  )
  for (f in files) {
    raw <- read_bytes(file.path(dir, f))
    expect_agree(list(raw), f)
    expect_agree(split_lines(raw), paste(f, "by line"))
  }
})

test_that("zufast and zuutf agree on every truncation of the stress test", {
  lines <- split_lines(read_bytes(file.path(fixtures(), "UTF-8-test.txt")))
  cuts <- unlist(
    lapply(lines, function(b) {
      lapply(seq_len(length(b)), function(k) b[seq_len(k)])
    }),
    recursive = FALSE
  )
  expect_gt(length(cuts), 10000L)
  expect_agree(cuts, "truncations")
})

test_that("zufast and zuutf agree through R on random strings", {
  set.seed(20261013)
  x <- lapply(sample(0:200, 1e5, TRUE), function(n) {
    as.raw(sample(0:255, n, TRUE))
  })
  expect_agree(x, "random")
})

test_that("zufast and zuutf's C table agree on a million random strings", {
  res <- random_sweep(1e6)
  expect_identical(res$strings, 1e6)
  expect_gt(res$valid, 1e5) # both outcomes are common
  expect_lt(res$valid, 9e5)
  expect_identical(
    res$disagreements,
    0,
    info = paste(res$first, collapse = " ")
  )
})

test_that("strict Base64 accepts exactly what zufast accepts", {
  set.seed(20261013)
  alphabet <- c(LETTERS, letters, 0:9, "+", "/", "-", "_", "=", " ", "\n", "*")
  inputs <- list()
  for (i in 1:20000) {
    b <- as.raw(sample(0:255, sample(0:40, 1), TRUE))
    url <- i %% 2 == 0
    s <- charToRaw(zuutf::base64_encode(b, url = url))
    k <- i %% 5
    if (k == 1 && length(s)) {
      s[sample(length(s), 1)] <- charToRaw(sample(alphabet, 1))
    }
    if (k == 2 && length(s)) {
      s <- s[-sample(length(s), 1)]
    }
    if (k == 3) {
      s <- c(s, charToRaw(sample(c("=", "A", " "), 1)))
    }
    if (k == 4) {
      s <- s[s != charToRaw("=")]
    }
    inputs[[i]] <- list(s = s, url = url)
  }
  for (url in c(FALSE, TRUE)) {
    sel <- Filter(function(e) e$url == url, inputs)
    x <- lapply(sel, `[[`, "s")
    z <- zufast_base64_strict(x, url = url)
    u <- lapply(x, function(s) {
      tryCatch(
        zuutf::base64_decode(s, url = url, forgiving = FALSE),
        zuutf_base64_error = function(e) NULL
      )
    })
    expect_identical(u, z, info = paste("url =", url))
    expect_gt(sum(!vapply(z, is.null, logical(1))), 1000L)
    expect_gt(sum(vapply(z, is.null, logical(1))), 1000L)
  }
})

test_that("the unicode_lipsum samples agree with zufast and with their own UTF-16 and UTF-32", {
  dir <- Sys.getenv("ZUUTF_LIPSUM")
  skip_if(!nzchar(dir) || !dir.exists(dir), "ZUUTF_LIPSUM is not set")
  utf8 <- list.files(dir, "[.]utf8[.]txt$", full.names = TRUE)
  expect_gt(length(utf8), 5L)
  for (f in utf8) {
    raw8 <- read_bytes(f)
    expect_agree(list(raw8), basename(f))
    expect_agree(split_lines(raw8), paste(basename(f), "by line"))
    text <- drop_feff(zuutf::utf_decode(raw8, "UTF-8"))
    raw16 <- read_bytes(sub("utf8", "utf16", f, fixed = TRUE))
    raw32 <- read_bytes(sub("utf8", "utf32", f, fixed = TRUE))
    expect_identical(
      drop_feff(zuutf::utf_decode(raw16, "UTF-16LE")),
      text,
      info = basename(f)
    )
    expect_identical(
      drop_feff(zuutf::utf_decode(raw32, "UTF-32LE")),
      text,
      info = basename(f)
    )
    expect_identical(
      zuutf::utf_encode(text, "UTF-16LE"),
      zuutf::utf_encode(drop_feff(zuutf::utf_decode(raw16)), "UTF-16LE"),
      info = basename(f)
    )
  }
})

test_that("files Windows PowerShell wrote decode to the text it was given", {
  dir <- Sys.getenv("ZUUTF_POWERSHELL")
  skip_if(
    !nzchar(dir) || !dir.exists(dir),
    "not on Windows, or no PowerShell files"
  )
  text <- zuutf::utf_decode(read_bytes(Sys.getenv("ZUUTF_SAMPLE")), "UTF-8")
  expected <- c(
    Unicode = "UTF-16LE",
    BigEndianUnicode = "UTF-16BE",
    UTF8 = "UTF-8"
  )
  for (enc in names(expected)) {
    raw <- read_bytes(file.path(dir, paste0(enc, ".txt")))
    expect_identical(zuutf::utf_detect(raw), expected[[enc]], info = enc) # its BOM
    expect_identical(zuutf::utf_decode(raw), text, info = enc)
    expect_identical(zuutf::utf_decode(raw, expected[[enc]]), text, info = enc)
  }
})
