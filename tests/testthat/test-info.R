test_that("zuutf_info() reports the version, the kernel and the kernels", {
  info <- zuutf_info()
  expect_named(info, c("simdutf", "kernel", "kernels"))
  expect_type(info$simdutf, "character")
  expect_type(info$kernel, "character")
  expect_s3_class(info$kernels, "data.frame")
  expect_named(info$kernels, c("name", "description", "supported"))
  expect_type(info$kernels$supported, "logical")
  expect_true("fallback" %in% info$kernels$name)
  expect_true(info$kernels$supported[info$kernels$name == "fallback"])
})

test_that("the kernel in use is a supported kernel", {
  info <- zuutf_info()
  expect_true(info$kernel %in% info$kernels$name[info$kernels$supported])
})

test_that("a kernel forced through the environment is the one in use", {
  # The kernel-matrix job sets SIMDUTF_FORCE_IMPLEMENTATION before R starts
  # and relies on this test: a run on the "unsupported" stub must fail, not
  # pass vacuously (design §10).
  forced <- Sys.getenv("SIMDUTF_FORCE_IMPLEMENTATION")
  skip_if(!nzchar(forced), "SIMDUTF_FORCE_IMPLEMENTATION is not set")
  expect_identical(zuutf_info()$kernel, forced)
})
