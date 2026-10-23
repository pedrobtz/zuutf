# Elapsed-time assertions (R7): off unless ZUUTF_TIMING_TESTS is true, since
# a loaded machine makes any timing flaky, and only against an installed
# package: devtools::load_all() compiles with -O0, where simdutf is a
# hundred times slower. Design §11's numbers come from
# tools/run-benchmarks.R; this only catches a kernel that has stopped being
# fast at all.

test_that("utf_valid() is faster than validUTF8() on a large input", {
  skip_unless_timing()
  withr::local_seed(20261013)
  text <- strrep(
    paste0("caf\u00e9 ", intToUtf8(sample(0x4e00:0x4fff, 100, TRUE)), " "),
    2^15
  )
  raw <- charToRaw(text)
  base <- min(replicate(3, system.time(validUTF8(text))[["elapsed"]]))
  ours <- min(replicate(3, system.time(utf_valid(raw))[["elapsed"]]))
  expect_lt(ours, base / 2)
})
