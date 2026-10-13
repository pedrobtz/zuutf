# Symbol isolation (design §12.2, alignment rule R3). simdutf is vendored by
# other projects too, and a second copy in the same process must never bind
# to ours. Nothing but R_init_zuutf may leave the shared object; on Linux
# with GCC, libstdc++'s own template instantiations may (weak, vague-linkage
# symbols the linker exports whatever the visibility flags say), as zufft
# accepts them.

test_that("the shared object exports R_init_zuutf and nothing of ours", {
  skip_if(is_instrumented_build(), "instrumented build")
  names <- exported_symbols()
  expect_true("R_init_zuutf" %in% names)
  others <- setdiff(names, "R_init_zuutf")
  others <- others[!libstdcxx_instantiation(others)]
  expect_identical(others, character())
})

test_that("no simdutf or zuutf internal symbol is exported", {
  names <- exported_symbols()
  expect_identical(grep("simdutf|zut_", names, value = TRUE), character())
})
