H <- "/private/tmp/claude-501/-Users-pbtz-src-github-com-pedrobtz/432a5e20-13bd-4b69-acab-05b86173939e/scratchpad/hunt"
.libPaths(c(file.path(H, "hunt-3/lib"), file.path(H, "lib")))
library(zuutf); library(zuutftest)
d <- function(s, ...) tryCatch(paste(as.character(base64_decode(s, ...)), collapse=""), zuutf_base64_error = function(e) paste0("offset ", e$offset))
api <- function(s, f) { r <- api_base64_decode(charToRaw(s), f); paste0("api err=", r[[1]], " count(0-based)=", r[[2]]) }
long <- strrep("QUJD", 40)
for (s in c("QUJDQ==AA", "QUJDQ\n==AA", "QUJDQ ==AAAAAAAAAAAAAAA", paste0(long, "Q ==", long), "QV==AAAA", "QUJDQV==AAAA", "QUJDQUJ=AAAA", "Q =QUJD", "Q=QUJD"))
  cat(sprintf("%-26s forgiving: %-11s %-32s strict: %-11s %s\n", encodeString(substr(s, 1, 24)), d(s), api(s, 0), d(s, forgiving = FALSE), api(s, 4)))
