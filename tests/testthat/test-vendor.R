# CRAN's compiled-code check applies to vendored code (design §8): the
# installed object must not reach printf, abort, exit or stderr, so that a
# future simdutf release cannot bring them in unnoticed.

test_that("the shared object references no stdio, abort or exit", {
  skip_if(is_instrumented_build(), "instrumented build")
  names <- referenced_symbols()
  # init.c always calls R_registerRoutines, from R.dll on Windows and as an
  # undefined symbol elsewhere, so an empty or misparsed table fails here
  # instead of passing the check below vacuously. (memcpy is no sentinel:
  # glibc builds reference it as __memcpy_chk or inline it.)
  expect_true("R_registerRoutines" %in% names)
  banned <- c("printf", "puts", "putchar", "abort", "exit", "_exit",
              "stderr", "stdout", "__stderrp", "__stdoutp", "__acrt_iob_func")
  expect_identical(intersect(names, banned), character())
})

test_that("the compiled-in simdutf is the manifest's version", {
  # Must match version_string in tools/vendor/manifest.tsv, which
  # tools/vendor/verify checks against simdutf.h from the other side.
  expect_identical(zuutf_info()$simdutf, "9.2.1")
})
