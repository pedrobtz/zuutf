# The three input shapes (design §5): a character vector, a raw vector (one
# element) or a list of raw vectors and NULLs (one element each). Returns
# what the C entry points read: a character vector of the bytes to use, a
# raw vector, or a list of raw vectors and NULLs.
#
# Character input is text: UTF-8 strings are taken as they are, Latin-1 and
# native strings through enc2utf8(), and "bytes" strings are refused. Its
# bytes are then UTF-8, so `encoding` must be "UTF-8" or "ASCII".
# useBytes = TRUE reads the bytes of every string as they are, in any
# encoding.
prepare_input <- function(x, encoding, useBytes = FALSE, call = NULL) {
  if (is.character(x)) {
    if (!isTRUE(useBytes) && !isFALSE(useBytes)) {
      abort_invalid_argument("`useBytes` must be TRUE or FALSE", call = call)
    }
    if (useBytes) {
      return(x)
    }
    if (any(Encoding(x) == "bytes")) {
      abort_invalid_argument(
        paste0(
          "`x` has strings marked \"bytes\"; ",
          "use `useBytes = TRUE` to read their bytes"
        ),
        call = call
      )
    }
    if (!encoding %in% c("UTF-8", "ASCII")) {
      abort_invalid_argument(
        sprintf(
          paste0(
            "a character vector is UTF-8 text, so `encoding` cannot be ",
            "\"%s\"; pass raw bytes, or use `useBytes = TRUE`"
          ),
          encoding
        ),
        call = call
      )
    }
    return(enc2utf8(x))
  }
  check_bytes_input(x, call = call)
  x
}

# Raw vector, or a list whose elements are raw vectors or NULL.
check_bytes_input <- function(x, call = NULL) {
  if (is.raw(x)) {
    return(invisible())
  }
  # a plain list: is.list() is TRUE for pairlists too, which C cannot read
  if (typeof(x) == "list" && !is.object(x)) {
    ok <- vapply(x, function(e) is.null(e) || is.raw(e), logical(1))
    if (all(ok)) {
      return(invisible())
    }
    abort_invalid_argument(
      sprintf(
        paste0(
          "every element of a list `x` must be a raw vector or NULL; ",
          "element %d is not"
        ),
        which(!ok)[1L]
      ),
      call = call
    )
  }
  abort_invalid_argument(
    "`x` must be a character vector, a raw vector or a list of raw vectors",
    call = call
  )
}

# Offsets and counts come back as doubles; integer when every value fits.
as_count <- function(v) {
  if (all(is.na(v) | v <= .Machine$integer.max)) as.integer(v) else v
}

# Names of the result: those of a character vector or a list.
with_names <- function(out, x) {
  if (!is.raw(x)) {
    names(out) <- names(x)
  }
  out
}
