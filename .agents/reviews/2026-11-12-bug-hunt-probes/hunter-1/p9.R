.libPaths("/private/tmp/claude-501/-Users-pbtz-src-github-com-pedrobtz/432a5e20-13bd-4b69-acab-05b86173939e/scratchpad/hunt/lib")
library(zuutf)
print(utf8ToInt(utf_decode(as.raw(c(0x00,0xe9)))))
# hostile session on conditions and results
options(OutDec = ",", scipen = -5, digits = 3, warn = 2)
r <- tryCatch(utf_decode(c(rep(as.raw(0x61), 99999), as.raw(0xff)), "UTF-8"), error = identity); print(conditionMessage(r)); str(r$offset)
r <- tryCatch(base64_decode(paste0(strrep("A", 123456), "!")), error = identity); print(conditionMessage(r))
print(utf_count(strrep("a", 1e6))); print(utf_length_as(strrep("a", 1e6), to = "UTF-32LE"))
print(base64_encode(as.raw(1:9), line_length = 4))
lat <- "caf\xe9"; Encoding(lat) <- "latin1"
print(utf_encode(c(lat, "x"), "UTF-16BE")); print(utf_valid(lat)); print(utf_decode(as.raw(c(0x63, 0xe9)), "Latin-1"))
print(sprintf("%s", 2^31 + 5)); print(sprintf("%s", 1e5)); print(sprintf("%s", 100000L))
# utf_error_at type
str(utf_error_at(list(as.raw(0xff), raw(0))))
# example claims from docs
le <- as.raw(c(0xff, 0xfe, 0x61, 0x00, 0x00, 0xd8))
print(utf_valid(le, "UTF-16")); print(utf_error_at(le, "UTF-16LE"))
print(utf_length_as("café", to = "UTF-16LE")); print(utf_length_as(as.raw(c(0x63, 0xe9)), from = "Latin-1", to = "UTF-8"))
print(tryCatch(base64_decode("aGVsbG8", forgiving = FALSE), zuutf_base64_error = function(e) e$offset))
print(base64_decode("aGVsbG8", url = TRUE, forgiving = FALSE, pad = FALSE))
print(tryCatch(base64_decode("aGVsbG8=", url = TRUE, forgiving = FALSE, pad = FALSE), error = function(e) e$offset))
print(tryCatch(base64_decode("aGVsbG9=", url = TRUE, forgiving = FALSE, pad = TRUE), error = function(e) e$offset))
print(tryCatch(base64_decode("aGVsbG9", url = TRUE, forgiving = FALSE, pad = FALSE), error = function(e) e$offset))
print(tryCatch(base64_decode("aGVs bG8", url = TRUE, forgiving = FALSE, pad = FALSE), error = function(e) e$offset))
# latin-1 length doc claim under error
print(utf_length_as("a中", to = "Latin-1"))
# UTF-16 partial unit doc: "ill-formed at its last, partial unit"
print(utf_error_at(as.raw(c(0x61,0,0x62)), "UTF-16LE")); print(utf_error_at(as.raw(c(0,0,0,0x61,0,0)), "UTF-32BE")); print(utf_error_at(as.raw(0x61), "UTF-32BE"))
print(utf_convert(as.raw(c(0x61,0,0x62)), "UTF-16LE", "UTF-8", invalid = "replace"))
print(utf_convert(as.raw(c(0,0,0,0x61,0,0)), "UTF-32BE", "UTF-8", invalid = "replace"))
print(utf_valid(as.raw(c(0x63,0xe9,0xff,0x00)), "Latin-1")); print(utf_valid(raw(0), "ASCII"))
