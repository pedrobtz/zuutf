#' Convert between Unicode encodings
#'
#' `utf_convert()` converts bytes from one encoding to another.
#' `utf_decode()` converts bytes to a character vector marked UTF-8.
#' `utf_encode()` converts a character vector to bytes.
#'
#' Every pair of UTF-8, UTF-16 and UTF-32 (either byte order) and Latin-1
#' converts in both directions. A leading byte-order mark that matches
#' `from` is dropped, and with `"UTF-16"`, `"UTF-32"` or `"auto"` it chooses
#' the encoding; the output never carries one.
#'
#' `invalid` says what happens to input that is ill-formed in `from`, and,
#' with a `"Latin-1"` target, to code points above U+00FF:
#'
#' * `"error"` raises a `zuutf_encoding_error` with the element's `index`,
#'   the `offset` of the problem in the input's code units and the
#'   `encoding` it lies in.
#' * `"replace"` writes U+FFFD (or `?` in Latin-1, which has no U+FFFD) in
#'   place of each maximal ill-formed subpart, as the WHATWG decoder does:
#'   one per unpaired surrogate in UTF-16, one per out-of-range unit in
#'   UTF-32, one per partial unit at the end, and one per unrepresentable
#'   code point.
#' * `"na"` gives `NA` (`NULL` in a list of raw vectors) for that element.
#'
#' R strings cannot hold U+0000, so `utf_decode()` raises `zuutf_nul_error`
#' with its `index` and `offset` whatever `invalid` says; `utf_convert()`
#' keeps it.
#'
#' @param x For `utf_convert()` and `utf_decode()`, a raw vector (one
#'   element) or a list of raw vectors (one element each, `NULL` for a
#'   missing one). For `utf_encode()`, a character vector, taken in its
#'   marked encoding; strings marked `"bytes"` are refused.
#' @param from The encoding of `x`: `"UTF-8"`, `"UTF-16LE"`, `"UTF-16BE"`,
#'   `"UTF-16"`, `"UTF-32LE"`, `"UTF-32BE"`, `"UTF-32"`, `"Latin-1"`, or
#'   `"auto"` for [utf_detect()]'s first candidate (UTF-8 when there is
#'   none). Matched without regard to case or hyphens.
#' @param to The target encoding: `"UTF-8"`, `"UTF-16LE"`, `"UTF-16BE"`,
#'   `"UTF-32LE"`, `"UTF-32BE"` or `"Latin-1"`.
#' @param invalid `"error"`, `"replace"` or `"na"`; see Details.
#'
#' @return `utf_convert()` and `utf_encode()`: a raw vector for a raw vector
#'   or a single string, otherwise a list of raw vectors (`NULL` for a
#'   missing or, under `"na"`, invalid element). `utf_decode()`: a character
#'   vector marked UTF-8, one string per element. A list or a character
#'   vector keeps its names.
#' @seealso [utf_detect()], [utf_valid()], [utf_length_as()]; [iconv()].
#' @export
#' @examples
#' # UTF-16 from a Windows tool, with its byte-order mark
#' b <- as.raw(c(0xff, 0xfe, 0x63, 0x00, 0x61, 0x00, 0x66, 0x00, 0xe9, 0x00))
#' utf_decode(b)                          # "auto" reads the BOM
#' utf_decode(b, "UTF-16LE")
#'
#' utf_encode("caf\u00e9", "UTF-16BE")
#' utf_convert(charToRaw("caf\u00e9"), "UTF-8", "Latin-1")
#'
#' # ill-formed input
#' bad <- as.raw(c(0x61, 0xff, 0x62))
#' utf_decode(bad, "UTF-8", invalid = "replace")
#' utf_decode(bad, "UTF-8", invalid = "na")
#' tryCatch(
#'   utf_decode(bad, "UTF-8"),
#'   zuutf_encoding_error = function(e) e$offset
#' )
#' utf_encode("\u4e2d", "Latin-1", invalid = "replace")
utf_convert <- function(x, from, to, invalid = c("error", "replace", "na")) {
  call <- sys.call()
  if (missing(from) || missing(to)) {
    abort_invalid_argument("`from` and `to` are required", call = call)
  }
  from <- match_encoding(from, c(enc_from, "auto"), "from", call)
  to <- match_encoding(to, enc_to, "to", call)
  invalid <- match_invalid(invalid, call)
  if (is.character(x)) {
    abort_invalid_argument(
      "`x` must be raw bytes; use utf_encode() for a character vector",
      call = call
    )
  }
  check_bytes_input(x, call = call)
  check_kernel(call)
  out <- run_convert(x, from, to, invalid, mode = 0L, call = call)
  if (is.raw(x)) out[[1L]] else with_names(out, x)
}

#' @rdname utf_convert
#' @export
utf_decode <- function(
  x,
  from = "auto",
  invalid = c("error", "replace", "na")
) {
  call <- sys.call()
  from <- match_encoding(from, c(enc_from, "auto"), "from", call)
  invalid <- match_invalid(invalid, call)
  if (is.character(x)) {
    abort_invalid_argument(
      "`x` must be raw bytes, not a character vector",
      call = call
    )
  }
  check_bytes_input(x, call = call)
  check_kernel(call)
  with_names(run_convert(x, from, "UTF-8", invalid, mode = 1L, call = call), x)
}

#' @rdname utf_convert
#' @export
utf_encode <- function(
  x,
  to = "UTF-16LE",
  invalid = c("error", "replace", "na")
) {
  call <- sys.call()
  to <- match_encoding(to, enc_to, "to", call)
  invalid <- match_invalid(invalid, call)
  if (!is.character(x)) {
    abort_invalid_argument("`x` must be a character vector", call = call)
  }
  bytes <- prepare_input(x, "UTF-8", FALSE, call)
  check_kernel(call)
  out <- run_convert(bytes, "UTF-8", to, invalid, mode = 0L, call = call)
  if (length(x) == 1L) out[[1L]] else with_names(out, x)
}

#' Detect the encoding of bytes
#'
#' Lists the encodings each element could be in. A byte-order mark decides
#' alone; otherwise the candidates are every encoding the bytes are valid
#' in, by the validators of simdutf, in the order UTF-8, UTF-16LE, UTF-16BE,
#' UTF-32LE, UTF-32BE. Latin-1 is never listed, since every byte string is
#' valid Latin-1, and pure ASCII text is valid UTF-16 too when its length is
#' even, which is why UTF-8 comes first.
#'
#' @param x A raw vector (one element) or a list of raw vectors.
#' @return For a raw vector, a character vector of candidate encodings, best
#'   first, and `character(0)` when none fits. For a list, a list of such
#'   vectors (`NULL` for a `NULL` element), keeping its names.
#' @seealso [utf_decode()], whose `from = "auto"` takes the first candidate.
#' @export
#' @examples
#' utf_detect(charToRaw("hello"))
#' utf_detect(as.raw(c(0xff, 0xfe, 0x68, 0x00)))   # a UTF-16LE BOM
#' utf_detect(as.raw(c(0xff, 0xff, 0xff)))
utf_detect <- function(x) {
  call <- sys.call()
  check_bytes_input(x, call = call)
  check_kernel(call)
  codes <- .Call(zut_detect, x)
  out <- lapply(codes, detected_names)
  if (is.raw(x)) out[[1L]] else with_names(out, x)
}

# simdutf's bitmask order (simdutf_encoding_type), which is design §6's.
detect_order <- c("UTF-8", "UTF-16LE", "UTF-16BE", "UTF-32LE", "UTF-32BE")

detected_names <- function(code) {
  if (is.na(code)) {
    return(NULL)
  }
  if (code < 0L) {
    return(names(zut_encodings)[match(-code, zut_encodings)])
  }
  detect_order[bitwAnd(code, c(1L, 2L, 4L, 8L, 16L)) != 0L]
}

match_invalid <- function(invalid, call = NULL) {
  choices <- c("error", "replace", "na")
  if (identical(invalid, choices)) {
    return("error")
  }
  if (
    !is.character(invalid) || length(invalid) != 1L || !invalid %in% choices
  ) {
    abort_invalid_argument(
      "`invalid` must be one of \"error\", \"replace\" or \"na\"",
      call = call
    )
  }
  invalid
}

# Run the C converter and raise the condition it reports, if any.
run_convert <- function(
  x,
  from,
  to,
  invalid,
  mode,
  call = NULL,
  simdutf_replacement = TRUE
) {
  policy <- match(invalid, c("error", "replace", "na")) - 1L
  res <- .Call(
    zut_convert,
    x,
    encoding_code(from),
    encoding_code(to),
    policy,
    mode,
    simdutf_replacement
  )
  status <- res[[2L]]
  if (status[[1L]] != 0) {
    raise_status(status, to, call)
  }
  res[[1L]]
}

raise_status <- function(status, to, call) {
  kind <- status[[1L]]
  index <- as_count(status[[2L]])
  offset <- as_count(status[[3L]])
  enc <- names(zut_encodings)[match(status[[4L]], zut_encodings)]
  switch(
    kind,
    abort_encoding_error(
      sprintf("element %d is ill-formed %s at offset %s", index, enc, offset),
      index = index,
      offset = offset,
      encoding = enc,
      call = call
    ),
    abort_encoding_error(
      sprintf(
        "element %d has a code point at offset %s that %s cannot represent",
        index,
        offset,
        to
      ),
      index = index,
      offset = offset,
      encoding = to,
      call = call
    ),
    abort_nul_error(
      sprintf(
        "element %d holds U+0000 at offset %s, which an R string cannot",
        index,
        offset
      ),
      index = index,
      offset = offset,
      call = call
    ),
    abort_size_error(
      sprintf("element %d converts to more bytes than R can hold", index),
      call = call
    ),
    abort_internal_error("unexpected status from the converter", call = call)
  )
}
