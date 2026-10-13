#' Encode and decode Base64
#'
#' `base64_encode()` writes bytes as Base64 text; `base64_decode()` reads
#' it back.
#'
#' Decoding is forgiving by default, as the WHATWG "forgiving-base64
#' decode" is: ASCII whitespace (space, tab, line feed, form feed, carriage
#' return) is skipped, padding is optional, and a final quantum of a single
#' character is an error. `forgiving = FALSE` reads RFC 4648 section 3.3
#' strictly: padding is required, the unused bits of the last character
#' must be zero, and whitespace is an error too.
#'
#' @param x For `base64_encode()`, a raw vector, or a single string, which
#'   is encoded as its UTF-8 bytes. For `base64_decode()`, a single string
#'   or a raw vector holding the Base64 text.
#' @param url Which alphabet: `FALSE` (the default) for the standard one
#'   with `+` and `/`, `TRUE` for the URL- and filename-safe one with `-`
#'   and `_`. `base64_decode()` also takes `NA`, which accepts either.
#' @param pad Whether `base64_encode()` writes `=` padding.
#' @param line_length `NULL` (the default) for one line, or a positive whole
#'   number: a line feed (`"\n"`) is written after every `line_length`
#'   characters, as MIME and PEM do with 76 and 64. For the CRLF of MIME, use
#'   [gsub()] on the result.
#' @param forgiving `TRUE` (the default) for WHATWG forgiving decoding,
#'   `FALSE` for strict RFC 4648; see Details.
#'
#' @return `base64_encode()`: a single string. `base64_decode()`: a raw
#'   vector. Input the chosen mode rejects raises a `zuutf_base64_error`
#'   whose `offset` is the 1-based position of the offending character.
#' @seealso [zuutf_error] for the condition classes.
#' @export
#' @examples
#' base64_encode(charToRaw("hello"))
#' base64_encode("hello", pad = FALSE)
#' base64_encode(as.raw(c(0xfb, 0xff)), url = TRUE)
#' base64_encode(as.raw(0:59), line_length = 64)
#'
#' rawToChar(base64_decode("aGVsbG8="))
#' base64_decode(" aGVs bG8 ")              # whitespace is skipped
#' base64_decode("-_8", url = TRUE)
#' base64_decode("+/8", url = NA)           # either alphabet
#' tryCatch(
#'   base64_decode("aGVsbG8", forgiving = FALSE),   # padding is required
#'   zuutf_base64_error = function(e) e$offset
#' )
base64_encode <- function(x, url = FALSE, pad = TRUE, line_length = NULL) {
  call <- sys.call()
  check_flag(url, "url", call = call)
  check_flag(pad, "pad", call = call)
  lines <- 0
  if (!is.null(line_length)) {
    if (!is.numeric(line_length) || length(line_length) != 1L ||
        is.na(line_length) || line_length < 1 || line_length != trunc(line_length)) {
      abort_invalid_argument(
        "`line_length` must be NULL or a positive whole number",
        call = call
      )
    }
    lines <- as.numeric(line_length)
  }
  x <- base64_input(x, utf8 = TRUE, call = call)
  check_kernel(call)
  # simdutf_base64_options: default 0, URL (unpadded) 1, default without
  # padding 2, URL with padding 3
  options <- if (url) (if (pad) 3L else 1L) else (if (pad) 0L else 2L)
  run_base64(.Call(zut_base64_encode, x, options, lines), call)
}

#' @rdname base64_encode
#' @export
base64_decode <- function(x, url = FALSE, forgiving = TRUE) {
  call <- sys.call()
  if (!is.logical(url) || length(url) != 1L) {
    abort_invalid_argument("`url` must be TRUE, FALSE or NA", call = call)
  }
  check_flag(forgiving, "forgiving", call = call)
  x <- base64_input(x, utf8 = FALSE, call = call)
  check_kernel(call)
  # simdutf_base64_options: default 0, URL 1, either alphabet 8
  options <- if (is.na(url)) 8L else if (url) 1L else 0L
  run_base64(.Call(zut_base64_decode, x, options, !forgiving), call)
}

check_flag <- function(x, arg, call = NULL) {
  if (!isTRUE(x) && !isFALSE(x)) {
    abort_invalid_argument(sprintf("`%s` must be TRUE or FALSE", arg), call = call)
  }
}

# One raw vector or one string (design §5, D14). A string to encode is
# taken as its UTF-8 bytes; a string to decode as its bytes, since Base64
# text is ASCII.
base64_input <- function(x, utf8, call = NULL) {
  if (is.raw(x)) {
    return(x)
  }
  if (!is.character(x) || length(x) != 1L || is.na(x)) {
    abort_invalid_argument(
      "`x` must be a raw vector or a single non-missing string; use lapply() for several",
      call = call
    )
  }
  if (utf8) {
    if (Encoding(x) == "bytes") {
      abort_invalid_argument(
        "`x` is marked \"bytes\"; pass charToRaw(x) to encode its bytes",
        call = call
      )
    }
    x <- enc2utf8(x)
  }
  x
}

run_base64 <- function(res, call) {
  status <- res[[2L]]
  switch(
    status[[1L]] + 1,
    res[[1L]],
    abort_base64_error(
      sprintf("invalid Base64 at offset %s", as_count(status[[2L]])),
      offset = as_count(status[[2L]]), call = call
    ),
    abort_size_error("the Base64 text would be longer than a string can hold", call = call),
    abort_internal_error("unexpected result from simdutf's Base64", call = call)
  )
}
