.libPaths("/private/tmp/claude-501/-Users-pbtz-src-github-com-pedrobtz/432a5e20-13bd-4b69-acab-05b86173939e/scratchpad/hunt/lib")
library(zuutf)
cat(Sys.getlocale("LC_CTYPE"), l10n_info()$`UTF-8`, "\n")
l1 <- "caf\xe9"; Encoding(l1) <- "latin1"; u8 <- "caf\xc3\xa9"; Encoding(u8) <- "UTF-8"; unk <- "caf\xe9"; unk8 <- "caf\xc3\xa9"
for (s in list(l1, u8, unk, unk8)) cat(Encoding(s), ":", tryCatch(base64_encode(s), error = function(e) conditionMessage(e)), "\n")
cat(tryCatch(base64_decode("QUJD\xe9"), error = function(e) conditionMessage(e)), "\n")
print(base64_decode(base64_encode(u8)))
