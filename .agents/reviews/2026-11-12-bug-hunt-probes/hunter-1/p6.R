.libPaths("/private/tmp/claude-501/-Users-pbtz-src-github-com-pedrobtz/432a5e20-13bd-4b69-acab-05b86173939e/scratchpad/hunt/lib")
library(zuutf)
t <- function(expr) { r <- tryCatch(expr, condition = function(e) e); if (inherits(r, "condition")) { cat("  COND<", class(r)[1], "> ", conditionMessage(r), "\n", sep=""); f <- unclass(r)[setdiff(names(unclass(r)), c("message","call"))]; if (length(f)) cat("   ", paste(names(f), sapply(f, format), sep="=", collapse=" "), "\n") } else { if (is.null(attributes(r))) str(r) else dput(r) }; invisible(r) }
p <- function(lbl, expr) { cat("#", lbl, "\n"); t(expr) }
x <- as.raw(0:40)
for (ll in list(NULL, 4, 4L, 5, 7, 8, 76, 3, 0, -1, 4.5, NA, NA_real_, NA_integer_, Inf, -Inf, NaN, 2^31, 2^31-1, 2^53+2, 1e300, "8", TRUE, c(8, 8), numeric(0), factor(8), Sys.Date(), as.difftime(8, units="secs"), list(8), matrix(8), 8+0i, structure(8, class="foo"), bit64 = NULL))
  p(paste("line_length", paste(deparse(ll), collapse="")), base64_encode(x, line_length = ll))
p("line == len", base64_encode(as.raw(0:5), line_length = 8)); p("line > len", base64_encode(as.raw(0:5), line_length = 9))
p("line trailing", base64_encode(as.raw(0:11), line_length = 8))
p("line empty", base64_encode(raw(0), line_length = 4))
p("line nopad", base64_encode(as.raw(0:6), line_length = 4, pad = FALSE))
p("line 5 url", base64_encode(as.raw(c(0xfb,0xff,0xfe,0xfb,0xff,0xfe,0xfb)), line_length = 5, url = TRUE))
for (u in list(TRUE, FALSE, NA, 1, 0, "TRUE", NULL, c(TRUE, FALSE), NA_integer_, NA_character_, logical(0), c(a = TRUE))) { p(paste("enc url", deparse(u)), base64_encode(as.raw(c(0xfb,0xff)), url = u)); p(paste("dec url", deparse(u)), base64_decode("-_8", url = u)); p(paste("dec std url", deparse(u)), base64_decode("+/8", url = u)) }
for (v in list(NA, 1, "T", NULL, c(TRUE,TRUE))) { p(paste("pad", deparse(v)), base64_encode(x, pad = v)); p(paste("dpad", deparse(v)), base64_decode("AA==", pad = v, forgiving = FALSE)); p(paste("forg", deparse(v)), base64_decode("AA==", forgiving = v)) }
p("pad F forgiving T", base64_decode("AA", pad = FALSE))
p("mixed NA", base64_decode("+_8-", url = NA))
p("NA strict padded", base64_decode("-_8=", url = NA, forgiving = FALSE))
p("NA strict unpadded pad=F", base64_decode("-_8", url = NA, forgiving = FALSE, pad = FALSE))
p("url strict padded", base64_decode("-_8=", url = TRUE, forgiving = FALSE))
p("url strict unpadded", base64_decode("-_8", url = TRUE, forgiving = FALSE))
p("url strict pad=F padded", base64_decode("-_8=", url = TRUE, forgiving = FALSE, pad = FALSE))
p("std strict pad=F", base64_decode("+/8", forgiving = FALSE, pad = FALSE))
p("std strict pad=F nonzero bits", base64_decode("+/9", forgiving = FALSE, pad = FALSE))
p("std strict nonzero bits", base64_decode("+/9=", forgiving = FALSE))
p("forgiving nonzero bits", base64_decode("+/9="))
p("strict ws", base64_decode("AA A=", forgiving = FALSE)); p("strict nl", base64_decode("AAAA\nAAAA", forgiving = FALSE))
p("offset after ws", base64_decode("aG Vs!bG8")); p("offset ws first", base64_decode("  !"))
p("single char", base64_decode("A")); p("5 chars", base64_decode("AAAAA")); p("pad only", base64_decode("=")); p("==", base64_decode("=="))
p("mid pad", base64_decode("AA==AAAA")); p("pad then ws", base64_decode("AA== ")); p("triple pad", base64_decode("AA===")); p("A=", base64_decode("A=")); p("AAA==", base64_decode("AAA=="))
p("vt", base64_decode("AA\vAA")); p("nbsp", base64_decode("AA AA"))
p("raw input", base64_decode(charToRaw("aGVsbG8="))); p("raw nul", base64_decode(as.raw(c(0x41,0x41,0x00,0x41))))
p("empty", base64_decode("")); p("ws only", base64_decode("  \n"))
p("chr vec", base64_encode(c("a","b"))); p("NA", base64_encode(NA_character_)); p("NA lgl", base64_decode(NA))
lat <- "\xe9"; Encoding(lat) <- "latin1"; byt <- "\xe9"; Encoding(byt) <- "bytes"
p("enc latin1", base64_encode(lat)); p("enc bytes", base64_encode(byt)); p("dec bytes-marked", base64_decode(structure("AAAA")))
bb <- "AAAA"; Encoding(bb) <- "bytes"; p("dec bytes", base64_decode(bb))
# roundtrip + reference
set.seed(2); bad <- 0
ref_ok <- requireNamespace("base64enc", quietly = TRUE); cat("base64enc:", ref_ok, "\n")
for (i in 1:3000) { r <- as.raw(sample(0:255, sample(0:50, 1), replace = TRUE))
  for (u in c(TRUE, FALSE)) for (pd in c(TRUE, FALSE)) { e <- base64_encode(r, url = u, pad = pd)
    for (uu in list(u, NA)) { if (!identical(base64_decode(e, url = uu), r)) bad <- bad + 1
      if (!identical(tryCatch(base64_decode(e, url = uu, forgiving = FALSE, pad = pd), error = function(e) "ERR"), r)) { bad <- bad + 1; if (bad < 5) { cat("strict fail", e, u, pd, format(uu), "\n") } } }
    ll <- sample(4:30, 1); el <- base64_encode(r, url = u, pad = pd, line_length = ll)
    exp <- if (nchar(e) == 0) "" else paste(substring(e, seq(1, nchar(e), ll), pmin(seq(1, nchar(e), ll) + ll - 1, nchar(e))), collapse = "\n")
    if (!identical(el, exp)) { bad <- bad + 1; if (bad < 8) cat("line mismatch", ll, "\n", el, "\n", exp, "\n") }
    if (!identical(base64_decode(el, url = u), r)) bad <- bad + 1
  }
  if (ref_ok && !identical(base64_encode(r), base64enc::base64encode(r))) bad <- bad + 1
}
cat("b64 mismatches:", bad, "\n")
