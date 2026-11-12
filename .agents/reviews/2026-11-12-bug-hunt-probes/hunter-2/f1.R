.libPaths("/private/tmp/claude-501/-Users-pbtz-src-github-com-pedrobtz/432a5e20-13bd-4b69-acab-05b86173939e/scratchpad/hunt/lib")
library(zuutf)
x <- as.raw(c(0x41,0x00, 0x00,0xd8, 0xd8))   # 'A', lone high surrogate, one odd byte
print(utf_convert(x, "UTF-16LE", "UTF-8", invalid = "replace"))
print(utf_convert(x[1:4], "UTF-16LE", "UTF-8", invalid = "replace"))
print(utf_convert(rev(c(x[2:1],x[4:3],x[5]))[5:1], "UTF-16BE", "UTF-8", invalid = "replace"))
print(utf_convert(as.raw(c(0x41,0,0,0xd8,0xd8)), "UTF-16LE", "UTF-16LE", invalid = "replace"))
