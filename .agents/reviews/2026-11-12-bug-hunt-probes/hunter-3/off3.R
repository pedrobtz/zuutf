.libPaths("/private/tmp/claude-501/-Users-pbtz-src-github-com-pedrobtz/432a5e20-13bd-4b69-acab-05b86173939e/scratchpad/hunt/lib")
library(zuutf)
d <- function(s, ...) tryCatch(paste(as.character(base64_decode(s, ...)), collapse=""), zuutf_base64_error = function(e) paste0("offset ", e$offset))
for (s in c("QUJDQ\n==+*", "QUJDQ==+*", "QUJDQ\n==AA", "QUJDQ==AA", "QUJDQQ\n==A", "QUJDQQ==A", "QUJDQQ\n==AAAA", "QUJDQQ==AAAA", "QUJDQQ= =AAAA", "QUJDQQ== AAAA","QUJDQQ\n=AAAA", "QUJDQUI\n=AAAA", "QUJDQUI=AAAA", "QUJDQUI=\nAAAA", "QUJD\n=AAA", "QUJD=AAA", "QUJD\n==AA", "QUJD==AA", "QQ\n==QQ==", "QQ==QQ==", "QQ\n==QUJD", "QQ\n==QUJDQUJDQUJD")) cat(sprintf("%-22s forgiving: %-10s\n", encodeString(s), d(s)))
