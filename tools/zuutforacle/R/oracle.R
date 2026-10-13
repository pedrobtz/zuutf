# zufast's answers for a list of raw vectors: a data frame with valid,
# offset (1-based, NA when valid) and count (code points; NA when invalid).
zufast_utf8 <- function(x) {
  res <- .Call(zor_utf8, x)
  data.frame(valid = res[[1]], offset = res[[2]], count = res[[3]])
}

# zufast's strict decoder over a list of raw vectors: a list holding the
# decoded raw vector, or NULL where zufast rejects the input. url selects
# the alphabet.
zufast_base64_strict <- function(x, url = FALSE) .Call(zor_base64, x, url)

# n random byte strings of lengths 0 to max_len from a xorshift seed, each
# checked by zufast and by zuutf's C table (validity, error offset, count).
# Returns the number of strings and of disagreements, and the first one.
random_sweep <- function(n, max_len = 200L, seed = 20261013) {
  .Call(zor_random, as.numeric(n), as.integer(max_len), as.numeric(seed))
}
