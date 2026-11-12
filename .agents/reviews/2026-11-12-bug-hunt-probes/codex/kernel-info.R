.libPaths('/private/tmp/claude-501/-Users-pbtz-src-github-com-pedrobtz/432a5e20-13bd-4b69-acab-05b86173939e/scratchpad/hunt-codex/lib')
library(zuutf)
info<-zuutf_info();cat('forced',Sys.getenv('SIMDUTF_FORCE_IMPLEMENTATION'),'reported',info$kernel,'\n');print(info$kernels)
for(fun in list(function()utf_valid(raw()),function()utf_count(raw()),function()utf_error_at(raw()),function()utf_decode(raw()),function()utf_encode(''),function()utf_convert(raw(),'UTF-8','UTF-8'),function()utf_length_as(raw(),to='UTF-8'),function()utf_detect(raw()),function()utf_is_ascii(raw()),function()base64_encode(raw()),function()base64_decode(''))) {
 e<-tryCatch(fun(),error=identity);cat(class(e)[1], '\n');stopifnot(inherits(e,'zuutf_internal_error'))
}
