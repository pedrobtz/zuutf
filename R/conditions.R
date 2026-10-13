#' Conditions raised by zuutf
#'
#' Every error zuutf raises inherits from `zuutf_error`, then `error` and
#' `condition`, so a caller can catch all of them, or one kind, with
#' [tryCatch()]. Test code should match on the class, never on the message.
#'
#' | Class | Fields | Raised when |
#' |---|---|---|
#' | `zuutf_invalid_argument` | | wrong type, unknown encoding name, a `"bytes"` string without `useBytes` |
#' | `zuutf_encoding_error` | `index`, `offset`, `encoding` | input that is ill-formed in its encoding under `invalid = "error"`, or a code point a Latin-1 target cannot represent |
#' | `zuutf_nul_error` | `index`, `offset` | [utf_decode()] meets U+0000, which an R string cannot hold |
#' | `zuutf_base64_error` | `offset` | Base64 input that [base64_decode()]'s mode rejects |
#' | `zuutf_size_error` | | an output longer than a string (2^31 - 1 bytes) or a raw vector can hold |
#' | `zuutf_internal_error` | | a simdutf result zuutf did not expect, or a kernel forced through `SIMDUTF_FORCE_IMPLEMENTATION` that this processor cannot run |
#'
#' `index` is the 1-based element of the input, `offset` the 1-based
#' position of the first error in the input's code units (bytes for UTF-8,
#' Latin-1 and ASCII; 16-bit units for UTF-16; 32-bit units for UTF-32),
#' counted after any byte-order mark, and `encoding` the name of the encoding.
#'
#' @name zuutf_error
#' @examples
#' tryCatch(
#'   utf_valid("abc", encoding = "EBCDIC"),
#'   zuutf_invalid_argument = function(e) class(e)
#' )
NULL

zuutf_condition <- function(class, message, ..., call = NULL) {
  structure(
    class = c(class, "zuutf_error", "error", "condition"),
    list(message = message, call = call, ...)
  )
}

abort_invalid_argument <- function(message, call = NULL) {
  stop(zuutf_condition("zuutf_invalid_argument", message, call = call))
}

abort_encoding_error <- function(message, index, offset, encoding, call = NULL) {
  stop(zuutf_condition(
    "zuutf_encoding_error", message,
    index = index, offset = offset, encoding = encoding, call = call
  ))
}

abort_nul_error <- function(message, index, offset, call = NULL) {
  stop(zuutf_condition(
    "zuutf_nul_error", message,
    index = index, offset = offset, call = call
  ))
}

abort_base64_error <- function(message, offset, call = NULL) {
  stop(zuutf_condition("zuutf_base64_error", message, offset = offset, call = call))
}

abort_size_error <- function(message, call = NULL) {
  stop(zuutf_condition("zuutf_size_error", message, call = call))
}

abort_internal_error <- function(message, call = NULL) {
  stop(zuutf_condition("zuutf_internal_error", message, call = call))
}

# SIMDUTF_FORCE_IMPLEMENTATION makes simdutf use the kernel it names without
# asking the processor (design §10): an unknown name gives its "unsupported"
# stub, which fails every call as if the input were bad, and a compiled-in
# kernel the processor lacks dies of an illegal instruction on first use.
# Both are refused here, before any simdutf code runs.
check_kernel <- function(call = NULL) {
  if (!.Call(zut_kernel_ok)) {
    abort_internal_error(
      paste0(
        "simdutf has no usable kernel: SIMDUTF_FORCE_IMPLEMENTATION is \"",
        Sys.getenv("SIMDUTF_FORCE_IMPLEMENTATION"),
        "\", which this processor cannot run or simdutf does not know"
      ),
      call = call
    )
  }
}
