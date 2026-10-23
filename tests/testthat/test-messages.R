# Message wording, one snapshot per condition kind. Tests elsewhere assert
# classes and fields only (CLAUDE.md); these catch a template that names
# the wrong field or encoding.

test_that("each condition's message reads as intended", {
  expect_snapshot(error = TRUE, utf_valid("a", "EBCDIC"))
  expect_snapshot(error = TRUE, base64_encode(raw(), line_length = 2))
  expect_snapshot(
    error = TRUE,
    utf_decode(list(raw(), as.raw(c(0x61, 0xff))), "UTF-8")
  )
  expect_snapshot(
    error = TRUE,
    utf_convert(as.raw(c(0x61, 0x00, 0x00, 0x4e)), "UTF-16LE", "Latin-1")
  )
  expect_snapshot(error = TRUE, utf_decode(as.raw(c(0x61, 0x00)), "UTF-8"))
  expect_snapshot(error = TRUE, base64_decode("aGVsbG8", forgiving = FALSE))
  # these two need a 2 GB input or a simdutf fault, so they come through
  # the status mapping directly
  expect_snapshot(
    error = TRUE,
    zuutf:::raise_status(c(4, 3, 1, 1), "UTF-8", NULL)
  )
  expect_snapshot(
    error = TRUE,
    zuutf:::raise_status(c(5, 3, 1, 1), "UTF-8", NULL)
  )
})
