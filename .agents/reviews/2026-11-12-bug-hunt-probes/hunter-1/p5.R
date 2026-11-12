.libPaths("/private/tmp/claude-501/-Users-pbtz-src-github-com-pedrobtz/432a5e20-13bd-4b69-acab-05b86173939e/scratchpad/hunt/lib")
library(zuutf)
set.seed(1)
bad <- 0
chk <- function(lbl, a, b, ctx = NULL) if (!identical(a, b)) { bad <<- bad + 1; if (bad < 40) { cat("MISMATCH", lbl, "\n"); str(a); str(b); if (!is.null(ctx)) print(ctx) } }
rnd_str <- function() { n <- sample(0:12, 1); cps <- sample(c(1:0x7f, 0x80:0xff, 0x100:0x7ff, 0x800:0xd7ff, 0xe000:0xfffd, 0x10000:0x10ffff, 0xfeff), n, replace = TRUE, prob = NULL); cps <- c(sample(c(0x41, 0xe9, 0x4e2d, 0x1f600, 0xfeff), sample(0:3,1), replace=TRUE), cps); if (!length(cps)) "" else intToUtf8(cps) }
tos <- c("UTF-8","UTF-16LE","UTF-16BE","UTF-32LE","UTF-32BE","Latin-1")
icn <- c("UTF-8"="UTF-8","UTF-16LE"="UTF-16LE","UTF-16BE"="UTF-16BE","UTF-32LE"="UTF-32LE","UTF-32BE"="UTF-32BE","Latin-1"="ISO-8859-1")
strip_bom <- function(s) sub("^﻿", "", s)
for (i in 1:3000) {
  s <- rnd_str(); r8 <- charToRaw(s); s0 <- strip_bom(s)
  chk("count vs nchar", utf_count(s), nchar(s0, "chars"), s)
  chk("count raw vs chr", utf_count(r8), utf_count(s), s)
  chk("count useBytes", utf_count(s, useBytes = TRUE), utf_count(s), s)
  chk("valid", utf_valid(s), TRUE, s); chk("error_at", utf_error_at(s), NA_integer_, s)
  chk("ascii", utf_is_ascii(s), all(utf8ToInt(s) < 128) || s == "", s)
  for (to in tos) {
    hasbig <- any(utf8ToInt(s0) > 255)
    e <- tryCatch(utf_encode(s, to), zuutf_encoding_error = function(e) e)
    if (to == "Latin-1" && hasbig) {
      if (!inherits(e, "condition")) chk("latin1 should fail", 1, 2, s)
      else { u <- utf8ToInt(s0); first <- which(u > 255)[1]; boff <- sum(nchar(intToUtf8(u[seq_len(first-1)], multiple=TRUE), "bytes")) + 1L; if (first == 1) boff <- 1L
             chk("latin1 offset", e$offset, as.integer(boff), s) }
      er <- utf_encode(s, to, invalid = "replace"); chk("latin1 replace len", length(er), nchar(s0)); chk("la na", utf_encode(s, to, invalid="na"), NULL)
      chk("length_as latin1", utf_length_as(s, to = to), nchar(s0), s)
      next
    }
    ref <- if (s0 == "") raw(0) else iconv(s0, "UTF-8", icn[[to]], toRaw = TRUE)[[1]]
    chk(paste("encode vs iconv", to), e, ref, s)
    chk(paste("convert vs encode", to), utf_convert(r8, "UTF-8", to), e, s)
    chk(paste("length_as", to), utf_length_as(s, to = to), length(e), s)
    chk(paste("length_as raw", to), utf_length_as(r8, "UTF-8", to), length(e), s)
    # back
    d <- utf_decode(e, to); chk(paste("decode roundtrip", to), d, strip_bom(s0)); 
    if (to != "Latin-1") chk("enc mark", Encoding(d), if (all(utf8ToInt(d) < 128) || d == "") "unknown" else "UTF-8")
    chk(paste("convert to utf8", to), utf_convert(e, to, "UTF-8"), charToRaw(strip_bom(s0)), s)
    chk(paste("count", to), utf_count(e, to), nchar(strip_bom(s0)), s)
    for (to2 in tos) { c2 <- tryCatch(utf_convert(e, to, to2), error = function(e) NULL); l2 <- utf_length_as(e, to, to2); if (!is.null(c2)) chk(paste("len", to, to2), l2, length(c2), s) }
  }
}
# random bytes: error_at vs valid vs decode error offset, list vs raw
for (i in 1:5000) {
  n <- sample(0:10, 1); r <- as.raw(sample(c(0x00, 0x41, 0x61, 0xc3, 0xa9, 0xe4, 0xb8, 0xad, 0xf0, 0x9f, 0x98, 0x80, 0xff, 0xfe, 0xef, 0xbb, 0xbf, 0xd8, 0xdc, 0xed, 0xa0, 0xc0, 0x80), n, replace = TRUE))
  for (enc in c("UTF-8","UTF-16LE","UTF-16BE","UTF-32LE","UTF-32BE","UTF-16","UTF-32","Latin-1","ASCII")) {
    v <- utf_valid(r, enc); ea <- utf_error_at(r, enc); cn <- utf_count(r, enc)
    chk(paste("valid/error_at", enc), v, is.na(ea), r); chk(paste("valid/count", enc), v, !is.na(cn), r)
    chk("list route", utf_error_at(list(raw(0), r, NULL), enc), c(NA, ea, NA), r)
    if (enc == "ASCII") { chk("is_ascii", utf_is_ascii(r), v, r); next }
    la <- utf_length_as(r, enc, "UTF-8"); chk("length_as NA", is.na(la), !v, r)
    cv <- tryCatch(utf_convert(r, enc, "UTF-8"), zuutf_encoding_error = function(e) e)
    if (v) { chk("conv valid", inherits(cv, "condition"), FALSE, r); chk("la == len", la, length(cv), list(r, enc))
      d <- tryCatch(utf_decode(r, enc), zuutf_nul_error = function(e) "NUL"); if (!identical(d, "NUL")) chk("decode==conv", charToRaw(d), cv, list(r, enc)) }
    else { chk("conv invalid", inherits(cv, "zuutf_encoding_error"), TRUE, list(r, enc)); if (inherits(cv, "condition")) chk("offset", cv$offset, ea, list(r, enc))
      chk("na", utf_convert(r, enc, "UTF-8", invalid = "na"), NULL)
      rp <- utf_convert(r, enc, "UTF-8", invalid = "replace"); chk("replace valid", validUTF8(rawToChar(rp[rp != 0])), TRUE, list(r, enc))
      chk("replace vs list", utf_convert(list(r), enc, "UTF-8", invalid = "replace")[[1]], rp) }
    if (enc == "UTF-8") { chk("validUTF8", v, validUTF8(rawToChar(r[r != 0])) || any(FALSE), r) ; s <- rawToChar(r[r!=0]); chk("chr useBytes", utf_valid(s, useBytes = TRUE), utf_valid(r[r != 0])) }
  }
}
cat("mismatches:", bad, "\n")
