.libPaths('/private/tmp/claude-501/-Users-pbtz-src-github-com-pedrobtz/432a5e20-13bd-4b69-acab-05b86173939e/scratchpad/hunt-codex/lib')
library(zuutf);library(zuutftest)
catch<-function(expr)tryCatch(expr,error=identity)
for(kernel in c('haswell','westmere','fallback')) {
 stopifnot(zuutf:::.zut_force_kernel(kernel))
 for(s in c('!AAAA','!AA=','!A=','!AAAA=','A!AAA','A!A=')) {
  cat('kernel',kernel,'input',s,'\n')
  for(pad in c(FALSE,TRUE)) {
   e<-catch(base64_decode(s,url=TRUE,forgiving=FALSE,pad=pad))
   cat('pad',pad,'class',class(e)[1],'offset',e$offset,'\n')
  }
  e<-api_base64_decode(charToRaw(s),flags=5L);cat('C strict code',e[[1]],'zero-based offset',e[[2]],'\n')
 }
}
