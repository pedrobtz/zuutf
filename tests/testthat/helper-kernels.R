# Run `code` once per kernel this processor supports, with that kernel
# forced in-process, and restore the kernel that was active before.
for_each_kernel <- function(code) {
  code <- substitute(code)
  env <- parent.frame()
  info <- zuutf_info()
  before <- info$kernel
  on.exit(zuutf:::.zut_force_kernel(before), add = TRUE)
  for (k in info$kernels$name[info$kernels$supported]) {
    expect_true(zuutf:::.zut_force_kernel(k))
    eval(code, list(kernel = k), env)
  }
  invisible()
}
