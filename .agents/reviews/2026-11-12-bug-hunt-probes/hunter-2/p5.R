.libPaths("/private/tmp/claude-501/-Users-pbtz-src-github-com-pedrobtz/432a5e20-13bd-4b69-acab-05b86173939e/scratchpad/hunt/lib")
library(zuutf)
t <- function(label, expr) { v <- tryCatch(expr, error=function(e) paste0("<", class(e)[1], " idx=", e$index, " off=", e$offset, "> ", conditionMessage(e))); cat(label, ": "); if (is.raw(v)) cat(paste(as.character(v), collapse=" "), "\n") else print(v) }
set.seed(7)
# runtime kernel switching, results must agree
cps <- sample(c(0x20:0x7e, 0xe9, 0x3042, 0x1f600, 0x10ffff, 0xffff), 3e5, TRUE)
s <- intToUtf8(cps); u8 <- charToRaw(s)
res <- list()
for (k in c("fallback","haswell","westmere","fallback","haswell")) {
  ok <- zuutf:::.zut_force_kernel(k); stopifnot(zuutf_info()$kernel == k)
  small <- utf_convert(as.raw(c(0x41,0xff)), "UTF-8", "UTF-16LE", invalid="replace")
  r <- lapply(c("UTF-16LE","UTF-16BE","UTF-32LE","UTF-32BE"), function(t) utf_convert(u8, "UTF-8", t))
  back <- lapply(seq_along(r), function(i) utf_convert(r[[i]], c("UTF-16LE","UTF-16BE","UTF-32LE","UTF-32BE")[i], "UTF-8"))
  bad <- c(u8[1:200000], as.raw(c(0xf0,0x9f)), u8[200001:length(u8)])
  res[[length(res)+1]] <- list(small, r, back, utf_error_at(bad), utf_convert(bad,"UTF-8","UTF-16BE",invalid="replace"), utf_count(u8), utf_length_as(u8, to="UTF-16LE"))
  stopifnot(all(vapply(back, identical, NA, u8)))
}
cat("kernels agree:", all(vapply(res, identical, NA, res[[1]])), "\n")
for (tt in c("UTF-16LE","UTF-16BE","UTF-32LE","UTF-32BE")) cat(tt, identical(res[[1]][[2]][[match(tt,c("UTF-16LE","UTF-16BE","UTF-32LE","UTF-32BE"))]], iconv(s,"UTF-8",tt,toRaw=TRUE)[[1]]), "\n")
cat("count", res[[1]][[6]] == length(cps), "erroff", res[[1]][[4]], "\n")
# huge first / tiny later and vice versa, UTF-32BE (scratch path) and UTF-16BE
big <- iconv(s,"UTF-8","UTF-32BE",toRaw=TRUE)[[1]]; tiny <- as.raw(c(0,0,0,0x41))
a <- utf_decode(list(big, tiny, raw(0), tiny), "UTF-32BE"); b <- utf_decode(list(tiny, raw(0), tiny, big), "UTF-32BE")
cat("big/tiny:", identical(a, c(s,"A","","A")), identical(b, c("A","","A",s)), "\n")
a <- utf_convert(list(big, tiny, big[1:8], tiny), "UTF-32BE", "UTF-32LE"); cat(identical(a[[2]], rev(tiny)), identical(a[[4]], rev(tiny)), identical(a[[3]], iconv(intToUtf8(cps[1:2]),"UTF-8","UTF-32LE",toRaw=TRUE)[[1]]), "\n")
# input not modified?
x <- as.raw(c(0,0,0,0x41,0,1,0xf6,0)); y <- as.raw(as.integer(x)); invisible(utf_convert(x,"UTF-32BE","UTF-32LE")); invisible(utf_convert(x,"UTF-32BE","UTF-8")); cat("input intact:", identical(x,y), "\n")
x <- as.raw(c(0x41,0,0,0,0,0xf6,1,0)); y <- as.raw(as.integer(x)); o <- utf_convert(x,"UTF-32LE","UTF-32BE"); cat("input intact:", identical(x,y), paste(o,collapse=" "), "\n")
# encode: latin1-marked, native, bytes
l <- "caf\xe9"; Encoding(l) <- "latin1"; t("latin1 marked", utf_encode(l, "UTF-8")); t("latin1 marked count", utf_count(l)); t("latin1 usebytes valid", utf_valid(l, useBytes=TRUE))
b <- "caf\xe9"; Encoding(b) <- "bytes"; t("bytes", utf_encode(b))
iu <- "a\xffb"; Encoding(iu) <- "UTF-8"; t("invalid utf8 str encode", utf_encode(iu)); t("replace", utf_encode(iu, "UTF-8", invalid="replace")); t("na", utf_encode(iu, invalid="na")); t("na vec", utf_encode(c(k=iu,j="a"), invalid="na"))
t("names decode", utf_decode(list(a=as.raw(0x41), b=NULL)))
t("ASCII from", utf_convert(as.raw(0x41), "ASCII", "UTF-8")); t("to UTF-16", utf_convert(as.raw(0x41), "UTF-8", "UTF-16"))
t("count ASCII bad", utf_count(as.raw(c(0x41,0x80)),"ASCII")); t("err ASCII", utf_error_at(as.raw(c(0x41,0x80)),"ASCII")); t("ASCII w/ utf8 BOM", utf_error_at(as.raw(c(0xef,0xbb,0xbf,0x41)),"ASCII"))
t("count latin1", utf_count(as.raw(c(0xff,0xfe,0x80)),"Latin-1"))
t("length_as chr latin1 from", utf_length_as("a", from="Latin-1", to="UTF-8"))
t("utf8 case-insens", utf_valid(as.raw(0x41), "utf8")); t("utf-16-le", utf_valid(as.raw(c(0x41,0)), "utf-16-le"))
