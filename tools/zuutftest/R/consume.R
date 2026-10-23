# Thin wrappers over the C table, called from C in src/consume.c.

api_struct_size <- function() .Call(ztt_struct_size)

api_kernel <- function() .Call(ztt_kernel)

api_kernel_ok <- function() .Call(ztt_kernel_ok)

# which: "utf8", "utf16le", "utf32", "ascii". Returns c(error, count).
api_validate <- function(x, which) .Call(ztt_validate, x, which)

api_count_utf8 <- function(x) .Call(ztt_count_utf8, x)

# which: "utf8_length_from_utf16le", "utf16_length_from_utf8",
# "base64_encoded_length", "base64_decoded_max_length".
api_length <- function(x, which, flags = 0L) {
  .Call(ztt_length, x, which, as.integer(flags))
}

# which: "utf16le_to_utf8", "utf8_to_utf16le", "latin1_to_utf8". cap NULL
# for the length the table says to allocate. Returns list(error, count, out).
api_convert <- function(x, which, cap = NULL) .Call(ztt_convert, x, which, cap)

api_base64_encode <- function(x, flags = 0L, cap = NULL) {
  .Call(ztt_base64_encode, x, as.integer(flags), cap)
}

api_base64_decode <- function(x, flags = 0L, cap = NULL) {
  .Call(ztt_base64_decode, x, as.integer(flags), cap)
}
