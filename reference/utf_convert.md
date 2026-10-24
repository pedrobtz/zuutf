# Convert between Unicode encodings

`utf_convert()` converts bytes from one encoding to another.
`utf_decode()` converts bytes to a character vector marked UTF-8.
`utf_encode()` converts a character vector to bytes.

## Usage

``` r
utf_convert(x, from, to, invalid = c("error", "replace", "na"))

utf_decode(x, from = "auto", invalid = c("error", "replace", "na"))

utf_encode(x, to = "UTF-16LE", invalid = c("error", "replace", "na"))
```

## Arguments

- x:

  For `utf_convert()` and `utf_decode()`, a raw vector (one element) or
  a list of raw vectors (one element each, `NULL` for a missing one).
  For `utf_encode()`, a character vector, taken in its marked encoding;
  strings marked `"bytes"` are refused.

- from:

  The encoding of `x`: `"UTF-8"`, `"UTF-16LE"`, `"UTF-16BE"`,
  `"UTF-16"`, `"UTF-32LE"`, `"UTF-32BE"`, `"UTF-32"`, `"Latin-1"`, or
  `"auto"` for
  [`utf_detect()`](https://pedrobtz.github.io/zuutf/reference/utf_detect.md)'s
  first candidate (UTF-8 when there is none). Matched without regard to
  case or hyphens.

- to:

  The target encoding: `"UTF-8"`, `"UTF-16LE"`, `"UTF-16BE"`,
  `"UTF-32LE"`, `"UTF-32BE"` or `"Latin-1"`.

- invalid:

  `"error"`, `"replace"` or `"na"`; see Details.

## Value

`utf_convert()` and `utf_encode()`: a raw vector for a raw vector or a
single string, otherwise a list of raw vectors (`NULL` for a missing or,
under `"na"`, invalid element). A single string that is `NA`, or invalid
under `"na"`, gives `NULL`, and its name is dropped, since a raw vector
has no element names. `utf_decode()`: a character vector marked UTF-8,
one string per element. A list, or a character vector of any other
length, keeps its names.

## Details

Every pair of UTF-8, UTF-16 and UTF-32 (either byte order) and Latin-1
converts in both directions. A leading byte-order mark that matches
`from` is dropped, and with `"UTF-16"`, `"UTF-32"` or `"auto"` it
chooses the encoding; the output never carries one.

`invalid` says what happens to input that is ill-formed in `from`, and,
with a `"Latin-1"` target, to code points above U+00FF:

- `"error"` raises a `zuutf_encoding_error` with the element's `index`,
  the `offset` of the problem in the input's code units and the
  `encoding` it lies in.

- `"replace"` writes U+FFFD (or `?` in Latin-1, which has no U+FFFD) in
  place of each maximal ill-formed subpart, as the WHATWG decoder does:
  one per unpaired surrogate in UTF-16, one per out-of-range unit in
  UTF-32, one per partial unit at the end, and one per unrepresentable
  code point.

- `"na"` gives `NA` (`NULL` in a list of raw vectors) for that element.

R strings cannot hold U+0000, so `utf_decode()` raises `zuutf_nul_error`
with its `index` and `offset` whatever `invalid` says; `utf_convert()`
keeps it.

## See also

[`utf_detect()`](https://pedrobtz.github.io/zuutf/reference/utf_detect.md),
[`utf_valid()`](https://pedrobtz.github.io/zuutf/reference/utf_valid.md),
[`utf_length_as()`](https://pedrobtz.github.io/zuutf/reference/utf_count.md);
[`iconv()`](https://rdrr.io/r/base/iconv.html).

## Examples

``` r
# UTF-16 from a Windows tool, with its byte-order mark
b <- as.raw(c(0xff, 0xfe, 0x63, 0x00, 0x61, 0x00, 0x66, 0x00, 0xe9, 0x00))
utf_decode(b)                          # "auto" reads the BOM
#> [1] "café"
utf_decode(b, "UTF-16LE")
#> [1] "café"

utf_encode("caf\u00e9", "UTF-16BE")
#> [1] 00 63 00 61 00 66 00 e9
utf_convert(charToRaw("caf\u00e9"), "UTF-8", "Latin-1")
#> [1] 63 61 66 e9

# ill-formed input
bad <- as.raw(c(0x61, 0xff, 0x62))
utf_decode(bad, "UTF-8", invalid = "replace")
#> [1] "a�b"
utf_decode(bad, "UTF-8", invalid = "na")
#> [1] NA
tryCatch(
  utf_decode(bad, "UTF-8"),
  zuutf_encoding_error = function(e) e$offset
)
#> [1] 2
utf_encode("\u4e2d", "Latin-1", invalid = "replace")
#> [1] 3f
```
