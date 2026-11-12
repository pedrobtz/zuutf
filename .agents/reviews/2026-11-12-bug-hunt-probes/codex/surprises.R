.libPaths('/private/tmp/claude-501/-Users-pbtz-src-github-com-pedrobtz/432a5e20-13bd-4b69-acab-05b86173939e/scratchpad/hunt-codex/lib')
library(zuutf)
for(enc in c('UTF-16LE','UTF-16BE')) {
 b<-if(enc=='UTF-16LE')as.raw(c(0,0xd8,0x41)) else as.raw(c(0xd8,0,0x41))
 cat(enc,'replacement output: ');print(utf_convert(b,enc,'UTF-8','replace'))
}
cat('BOM-like R character text count: ');print(utf_count('\ufeffA'))
cat('BOM-like R character text encode: ');print(utf_encode('\ufeffA','UTF-8'))
cat('Latin-1 length for euro: ');print(utf_length_as('\u20ac',to='Latin-1'))
cat('ASCII even length detection: ');print(utf_detect(charToRaw('AB')))
cat('foreign BOM detected as explicit UTF16LE: ');print(utf_convert(as.raw(c(255,254,0,0)),'UTF-16LE','UTF-8'))
cat('same mark auto: ');print(utf_convert(as.raw(c(255,254,0,0)),'auto','UTF-8'))
cat('length_as message: ');print(tryCatch(utf_length_as('A',from='Latin-1',to='UTF-8'),error=conditionMessage))
