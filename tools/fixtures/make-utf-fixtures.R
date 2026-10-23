# Regenerate the UTF-16 and UTF-32 fixtures of tests/testthat/fixtures from
# tools/fixtures/sample.txt with iconv(), so that they come from a converter
# other than zuutf. Run from the package root:
#
#   Rscript tools/fixtures/make-utf-fixtures.R
#
# Writes sample.<enc>[-bom].txt and prints their SHA-256 for MANIFEST.tsv.
text <- readLines("tools/fixtures/sample.txt", encoding = "UTF-8")
text <- paste0(paste(text, collapse = "\n"), "\n")
dir <- "tests/testthat/fixtures"
boms <- list(
  "utf16le" = as.raw(c(0xff, 0xfe)),
  "utf16be" = as.raw(c(0xfe, 0xff)),
  "utf32le" = as.raw(c(0xff, 0xfe, 0, 0)),
  "utf32be" = as.raw(c(0, 0, 0xfe, 0xff))
)
targets <- c(
  utf8 = "UTF-8",
  utf16le = "UTF-16LE",
  utf16be = "UTF-16BE",
  utf32le = "UTF-32LE",
  utf32be = "UTF-32BE"
)
for (key in names(targets)) {
  bytes <- iconv(text, "UTF-8", targets[[key]], toRaw = TRUE)[[1L]]
  stopifnot(!is.null(bytes))
  writeBin(bytes, file.path(dir, paste0("sample.", key, ".txt")))
  if (!is.null(boms[[key]])) {
    writeBin(
      c(boms[[key]], bytes),
      file.path(dir, paste0("sample.", key, "-bom.txt"))
    )
  }
}
files <- list.files(dir, "^sample\\.", full.names = TRUE)
sha <- Sys.which(c("sha256sum", "shasum"))
sha <- sha[nzchar(sha)][1L]
args <- if (basename(sha) == "shasum") c("-a", "256") else character()
for (f in files) {
  cat(system2(sha, c(args, shQuote(f)), stdout = TRUE), "\n")
}
