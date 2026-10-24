# Encoding names (design §5), matched without regard to case or hyphens.
# The codes are zut_enc in src/zut_input.h.
zut_encodings <- c(
  "UTF-8" = 1L,
  "UTF-16LE" = 2L,
  "UTF-16BE" = 3L,
  "UTF-32LE" = 4L,
  "UTF-32BE" = 5L,
  "Latin-1" = 6L,
  "ASCII" = 7L,
  "UTF-16" = 8L,
  "UTF-32" = 9L
)

# The names each argument accepts. "UTF-16" and "UTF-32" are input only
# (a byte-order mark decides); "ASCII" is for validation only.
enc_validate <- names(zut_encodings)
enc_from <- setdiff(names(zut_encodings), "ASCII")
enc_to <- c("UTF-8", "UTF-16LE", "UTF-16BE", "UTF-32LE", "UTF-32BE", "Latin-1")

encoding_key <- function(x) toupper(gsub("-", "", x, fixed = TRUE))

# The canonical name of `name`, which must be one of `allowed`.
match_encoding <- function(name, allowed, arg, call = NULL) {
  if (!is.character(name) || length(name) != 1L || is.na(name)) {
    abort_invalid_argument(
      sprintf("`%s` must be a single encoding name", arg),
      call = call
    )
  }
  hit <- allowed[encoding_key(allowed) == encoding_key(name)]
  if (length(hit) != 1L) {
    abort_invalid_argument(
      sprintf(
        "`%s` must be one of %s, not \"%s\"",
        arg,
        paste0("\"", allowed, "\"", collapse = ", "),
        name
      ),
      call = call
    )
  }
  hit
}

# "auto" is conversion input only (utf_detect()'s first candidate), so it is
# not among zut_encodings and no other argument accepts it.
encoding_code <- function(name) {
  if (name == "auto") 10L else zut_encodings[[name]]
}
