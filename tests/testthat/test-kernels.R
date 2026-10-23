test_that("utf_valid() agrees with validUTF8() on every supported kernel", {
  withr::local_seed(20261013)
  inputs <- list(
    raw(0),
    charToRaw("hello"),
    as.raw(c(0xc3, 0xa9)), # U+00E9
    as.raw(c(0xf0, 0x9f, 0x98, 0x80)), # U+1F600
    as.raw(c(0xc0, 0xaf)), # overlong
    as.raw(c(0xed, 0xa0, 0x80)), # surrogate
    as.raw(c(0xf4, 0x90, 0x80, 0x80)), # above U+10FFFF
    as.raw(c(0xe2, 0x82)), # truncated
    as.raw(0xff)
  )
  # every length around the 64-byte blocks the SIMD kernels work in
  for (n in c(1:130, 4090:4100)) {
    inputs[[length(inputs) + 1L]] <- as.raw(sample(1:255, n, TRUE)) # no NUL: rawToChar() refuses it
    inputs[[length(inputs) + 1L]] <- charToRaw(strrep("a", n))
  }
  expected <- vapply(
    inputs,
    function(b) validUTF8(rawToChar(b, multiple = FALSE)),
    logical(1)
  )
  for_each_kernel({
    got <- utf_valid(inputs)
    expect_identical(got, expected, info = kernel)
  })
})

test_that("forcing an unknown kernel fails and leaves the kernel alone", {
  before <- zuutf_info()$kernel
  expect_false(zuutf:::.zut_force_kernel("no-such-kernel"))
  expect_identical(zuutf_info()$kernel, before)
})
