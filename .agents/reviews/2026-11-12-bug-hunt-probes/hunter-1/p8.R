.libPaths("/private/tmp/claude-501/-Users-pbtz-src-github-com-pedrobtz/432a5e20-13bd-4b69-acab-05b86173939e/scratchpad/hunt/lib")
library(zuutf)
t <- function(expr) { r <- tryCatch(expr, condition = function(e) e); if (inherits(r, "condition")) { cat("  COND<", class(r)[1], "> ", conditionMessage(r), "\n", sep=""); f <- unclass(r)[setdiff(names(unclass(r)), c("message","call"))]; if (length(f)) cat("   ", paste(names(f), sapply(f, format), sep="=", collapse=" "), "\n") } else { if (is.null(attributes(r))) str(r) else dput(r) }; invisible(r) }
p <- function(lbl, expr) { cat("#", lbl, "\n"); t(expr) }
h <- function(...) as.raw(c(...))
p("detect bom8 invalid", utf_detect(h(0xef,0xbb,0xbf,0xff)))
p("detect FE FF", utf_detect(h(0xfe,0xff))); p("detect FF FE 00 00", utf_detect(h(0xff,0xfe,0,0))); p("detect 00 00 FE FF", utf_detect(h(0,0,0xfe,0xff)))
p("detect FF FE odd", utf_detect(h(0xff,0xfe,0x61))); p("detect none", utf_detect(h(0xff,0xff,0xff)))
p("decode FF FE 00 00", utf_decode(h(0xff,0xfe,0,0))); p("decode 16LE FF FE 00 00", utf_decode(h(0xff,0xfe,0,0), "UTF-16LE")); p("decode UTF-16 generic FF FE 00 00", utf_decode(h(0xff,0xfe,0,0), "UTF-16"))
p("convert auto FF FE 00 00", utf_convert(h(0xff,0xfe,0,0), "auto", "UTF-8"))
p("auto none err", utf_decode(h(0x61, 0xff,0xff,0xff))); p("auto none replace", utf_decode(h(0x61,0xff,0xff,0xff), invalid="replace"))
p("auto list", utf_decode(list(a = h(0xff,0xfe,0x61,0), b = h(0xfe,0xff,0,0x62), c = charToRaw("é"), d = h(0,0,0xfe,0xff,0,0,0,0x63), e = NULL, f = raw(0))))
p("auto list err enc", utf_decode(list(charToRaw("ok"), h(0xfe,0xff,0xd8,0x00))))
p("auto odd", utf_decode(h(0x61,0x00,0x62)))   # valid UTF-8 with NUL
p("auto 61 00", utf_decode(h(0x61,0x00)))
p("auto 00 61", utf_decode(h(0x00,0x61)))
p("auto e9 00 (16LE only)", utf_decode(h(0xe9,0x00))); p("detect e9 00", utf_detect(h(0xe9,0x00)))
p("auto 00 e9", utf_decode(h(0x00,0xe9))); p("detect 00 e9", utf_detect(h(0x00,0xe9)))
p("UTF-16 generic no bom", utf_decode(h(0x00,0x61), "UTF-16")); p("UTF-16 generic LE bom", utf_decode(h(0xff,0xfe,0x61,0), "UTF-16")); p("UTF-32 generic no bom", utf_decode(h(0,0,0,0x61), "UTF-32")); p("UTF-32 LE bom", utf_decode(h(0xff,0xfe,0,0,0x61,0,0,0), "UTF-32"))
p("UTF-16 generic w/ UTF-32LE bom", utf_decode(h(0xff,0xfe,0,0,0x61,0), "UTF-16"))
p("count UTF-16 generic", utf_count(h(0xff,0xfe,0x61,0), "UTF-16")); p("length_as generic", utf_length_as(h(0xff,0xfe,0x61,0), "UTF-16", "UTF-8"))
p("double BOM 16", utf_decode(h(0xff,0xfe,0xff,0xfe,0x61,0), "UTF-16LE"))
p("latin1 with bom8 bytes", utf_decode(h(0xef,0xbb,0xbf,0x61), "Latin-1"))
set.seed(3); bad <- 0
for (i in 1:20000) { r <- as.raw(sample(c(0x00, 0x41, 0x61, 0xc3, 0xa9, 0xff, 0xfe, 0xef, 0xbb, 0xbf, 0xd8, 0xdc, 0x01), sample(0:8, 1), replace = TRUE))
  d <- utf_detect(r); enc <- if (length(d)) d[1] else "UTF-8"
  for (iv in c("error","replace","na")) { a <- tryCatch(utf_decode(r, invalid = iv), error = function(e) c(class(e)[1], e$index, e$offset, e$encoding)); b <- tryCatch(utf_decode(r, enc, invalid = iv), error = function(e) c(class(e)[1], e$index, e$offset, e$encoding))
    if (!identical(a, b)) { bad <- bad + 1; if (bad < 6) { print(r); print(d); print(a); print(b) } }
    a <- tryCatch(utf_convert(r, "auto", "UTF-16BE", invalid = iv), error = function(e) c(class(e)[1], e$index, e$offset, e$encoding)); b <- tryCatch(utf_convert(r, enc, "UTF-16BE", invalid = iv), error = function(e) c(class(e)[1], e$index, e$offset, e$encoding))
    if (!identical(a, b)) { bad <- bad + 1; if (bad < 6) { print(r); print(d); print(a); print(b) } } }
  # detect claim: candidates are every encoding bytes are valid in (no BOM case)
  hasbom <- (length(r) >= 2 && (identical(r[1:2], h(0xff,0xfe)) || identical(r[1:2], h(0xfe,0xff)))) || (length(r) >= 3 && identical(r[1:3], h(0xef,0xbb,0xbf))) || (length(r) >= 4 && identical(r[1:4], h(0,0,0xfe,0xff)))
  if (!hasbom) { v <- c("UTF-8","UTF-16LE","UTF-16BE","UTF-32LE","UTF-32BE"); vv <- v[vapply(v, function(e) utf_valid(r, e), NA)]; if (!identical(vv, d)) { bad <- bad + 1; if (bad < 12) { cat("detect vs valid\n"); print(r); print(d); print(vv) } } }
}
cat("auto mismatches:", bad, "\n")
lat <- "caf\xe9"; Encoding(lat) <- "latin1"
mix <- c(a = lat, b = "café", c = NA, d = "x")
p("mixed count", utf_count(mix)); p("mixed encode", utf_encode(mix, "Latin-1")); p("mixed len", utf_length_as(mix, to = "UTF-8")); p("mixed ascii", utf_is_ascii(mix)); p("mixed valid ASCII", utf_valid(mix, "ASCII")); p("mixed count ascii", utf_count(mix, "ASCII")); p("mixed err ascii", utf_error_at(mix, "ASCII"))
p("mixed useBytes latin1", utf_count(mix, "Latin-1", useBytes = TRUE)); p("mixed useBytes utf8", utf_error_at(mix, "UTF-8", useBytes = TRUE))
p("useBytes utf16 on chr", utf_valid("ab", "UTF-16LE", useBytes = TRUE))
byt <- "caf\xe9"; Encoding(byt) <- "bytes"
p("bytes in vec", utf_count(c("a", byt))); p("bytes useBytes", utf_count(c("a", byt), "Latin-1", useBytes = TRUE)); p("encode bytes", utf_encode(c("a", byt))); p("length_as bytes", utf_length_as(byt, to = "UTF-8"))
p("do.call call", conditionCall(tryCatch(do.call(utf_decode, list(as.raw(0xff), "UTF-8")), error = identity)))
p("lapply call", conditionCall(tryCatch(lapply(list(as.raw(0xff)), utf_decode, from = "UTF-8"), error = identity)))
p("info", names(zuutf_info())); p("info partial", zuutf_info()$kern)
p("print err", print(tryCatch(utf_decode(as.raw(0xff), "UTF-8"), error = identity)))
