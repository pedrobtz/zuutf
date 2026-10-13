test_that("the namespace loads with its shared object", {
  expect_true(isNamespaceLoaded("zuutf"))
  expect_true("zuutf" %in% names(getLoadedDLLs()))
})
