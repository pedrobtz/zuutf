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

# Runs the read-only members from `threads` threads at once over `inputs`
# (a list of raw vectors), `rounds` times each, and compares every result
# with a single-threaded run (src/threads.c). Returns a list of counts: all
# of mismatched, unstable, overruns, failed and kernel_differs must be 0.
api_threads <- function(inputs, threads = 8L, rounds = 20L) {
  .Call(ztt_threads, inputs, as.integer(threads), as.integer(rounds))
}

# The inputs the threaded test uses: empty, ASCII, mixed UTF-8 long enough
# for every SIMD path, and invalid variants with the error early, late and
# at the end, so threads see both results on the same buffers.
thread_inputs <- function(seed = 85L) {
  old <- if (exists(".Random.seed", globalenv())) get(".Random.seed", globalenv())
  on.exit(if (is.null(old)) rm(".Random.seed", envir = globalenv()) else
    assign(".Random.seed", old, globalenv()))
  set.seed(seed)
  cps <- function(n) {
    x <- c(
      sample(0x20:0x7e, n, TRUE),
      sample(0x80:0x7ff, n, TRUE),
      sample(c(0x800:0xd7ff, 0xe000:0xfffd), n, TRUE),
      sample(0x10000:0x10ffff, n, TRUE)
    )
    charToRaw(enc2utf8(intToUtf8(sample(x))))
  }
  mixed <- cps(16384L)
  ascii <- charToRaw(strrep("zugodb worker threads ", 4000L))
  at <- function(x, i, b) {
    x[i] <- as.raw(b)
    x
  }
  list(
    raw(0),
    ascii,
    mixed,
    cps(7L),
    at(mixed, 9L, 0xff),
    at(mixed, length(mixed) - 100L, 0xc0),
    c(mixed, as.raw(0xe4)),
    c(ascii, as.raw(c(0xed, 0xa0, 0x80))),
    at(ascii, length(ascii), 0x80),
    sample(as.raw(0:255), 70000L, TRUE)
  )
}
