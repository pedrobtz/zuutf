#' Count code points and conversion lengths
#'
#' `utf_count()` counts the code points (characters, in the sense of
#' `nchar(type = "chars")`) of each element. `utf_length_as()` gives
#' the number of bytes converting each element from `from` to `to` will
#' produce, without converting it.
#'
#' A leading byte-order mark that matches the input encoding is skipped and
#' not counted, and a conversion writes none, so neither counts it. An
#' element that is ill-formed in its encoding gives `NA`; [utf_error_at()][utf_valid]
#' says where. With a `"Latin-1"` target every code point is one byte, those
#' above U+00FF included, since a conversion writes one byte for each of
#' them too (an error, `?` or `NA`, as its `invalid` argument says).
#'
#' @inheritParams utf_valid
#' @param encoding,from The encoding of the input: `"UTF-8"`, `"UTF-16LE"`,
#'   `"UTF-16BE"`, `"UTF-16"`, `"UTF-32LE"`, `"UTF-32BE"`, `"UTF-32"` or
#'   `"Latin-1"`, matched without regard to case or hyphens; `utf_count()`
#'   also takes `"ASCII"`. A character vector is UTF-8 text, so for one only
#'   `"UTF-8"` applies, unless `useBytes = TRUE` in `utf_count()`.
#' @param to The target encoding: `"UTF-8"`, `"UTF-16LE"`, `"UTF-16BE"`,
#'   `"UTF-32LE"`, `"UTF-32BE"` or `"Latin-1"`.
#'
#' @return An integer vector, one value per element, `NA` where the element
#'   is `NA`, `NULL` or ill-formed. Counts beyond the integer range come back
#'   as doubles. A character vector or a list keeps its names.
#' @seealso [utf_valid()]; [nchar()].
#' @export
#' @examples
#' utf_count(c("abc", "café", "\U0001f600", NA))
#' utf_count(as.raw(c(0x3d, 0xd8, 0x00, 0xde)), "UTF-16LE")   # one emoji
#'
#' utf_length_as("café", to = "UTF-16LE")   # 8 bytes
#' utf_length_as("\U0001f600", to = "UTF-16LE")  # a surrogate pair: 4 bytes
#' utf_length_as(as.raw(c(0x63, 0xe9)), from = "Latin-1", to = "UTF-8")
utf_count <- function(x, encoding = "UTF-8", useBytes = FALSE) {
  call <- sys.call()
  encoding <- match_encoding(encoding, enc_validate, "encoding", call)
  x0 <- x
  x <- prepare_input(x, encoding, useBytes, call)
  check_kernel(call)
  with_names(as_count(.Call(zut_validate, x, encoding_code(encoding), 2L)), x0)
}

#' @rdname utf_count
#' @export
utf_length_as <- function(x, from = "UTF-8", to) {
  call <- sys.call()
  from <- match_encoding(from, enc_from, "from", call)
  if (missing(to)) {
    abort_invalid_argument("`to` is required", call = call)
  }
  to <- match_encoding(to, enc_to, "to", call)
  x0 <- x
  x <- prepare_input(x, from, FALSE, call)
  check_kernel(call)
  with_names(
    as_count(.Call(zut_length_as, x, encoding_code(from), encoding_code(to))),
    x0
  )
}
