#' zuutf: Fast Unicode validation and transcoding with simdutf
#'
#' Validates text and converts it between UTF-8, UTF-16 and UTF-32 in
#' either byte order and Latin-1, counts characters, detects encodings, and
#' encodes and decodes Base64, through a bundled copy of the simdutf
#' library. Every validation and conversion can report the position of the
#' first ill-formed sequence, in the units of the input.
#'
#' @useDynLib zuutf, .registration = TRUE
#' @keywords internal
"_PACKAGE"
