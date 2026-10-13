# Validate text in a Unicode encoding

`utf_valid()` tells whether each element is well-formed in `encoding`.
`utf_error_at()` gives the position of its first error. `utf_is_ascii()`
tells whether each element is pure ASCII, bytes 0x00 to 0x7F.

## Usage

``` r
utf_valid(x, encoding = "UTF-8", useBytes = FALSE)

utf_error_at(x, encoding = "UTF-8", useBytes = FALSE)

utf_is_ascii(x)
```

## Arguments

- x:

  A character vector, a raw vector (one element), or a list of raw
  vectors (one element each). `NA` strings and `NULL` list elements give
  `NA`.

- encoding:

  The encoding to check against: `"UTF-8"`, `"UTF-16LE"`, `"UTF-16BE"`,
  `"UTF-16"`, `"UTF-32LE"`, `"UTF-32BE"`, `"UTF-32"`, `"Latin-1"` or
  `"ASCII"`, matched without regard to case or hyphens (`"utf8"` is
  `"UTF-8"`). A character vector is UTF-8 text, so for one only
  `"UTF-8"` and `"ASCII"` apply unless `useBytes = TRUE`.

- useBytes:

  For a character vector: `FALSE` (the default) takes each string in its
  marked encoding and checks its UTF-8 form, refusing strings marked
  `"bytes"`; `TRUE` checks the bytes of every string as they are, which
  is how to check a string R believes is UTF-8.

## Value

`utf_valid()` and `utf_is_ascii()`: a logical vector, one value per
element. `utf_error_at()`: an integer vector of 1-based offsets of the
first error, in the input's code units (bytes for UTF-8, Latin-1 and
ASCII; 16-bit units for UTF-16; 32-bit units for UTF-32), counted after
any byte-order mark, and `NA` where the element is valid. A character
vector or a list keeps its names.

## Details

Well-formed means what Unicode says: in UTF-8, no overlong forms, no
encoded surrogates (U+D800 to U+DFFF), nothing above U+10FFFF and no
truncated sequence; in UTF-16, no unpaired surrogate; in UTF-32, no
surrogate and nothing above U+10FFFF. A UTF-16 or UTF-32 input whose
length is not a whole number of code units is ill-formed at its last,
partial unit. Every byte string is valid Latin-1.

A leading byte-order mark that matches `encoding` is skipped. With
`"UTF-16"` or `"UTF-32"`, a byte-order mark chooses the byte order, and
without one the input is big-endian.

## See also

[`utf_count()`](https://pedrobtz.github.io/zuutf/reference/utf_count.md);
[`validUTF8()`](https://rdrr.io/r/base/validUTF8.html), which answers
yes or no for UTF-8 only.

## Examples

``` r
utf_valid(c("abc", "café", NA))
#> [1] TRUE TRUE   NA
utf_valid(as.raw(c(0xc3, 0x28)))            # a truncated sequence
#> [1] FALSE
utf_error_at(as.raw(c(0x61, 0x62, 0xff)))   # third byte
#> [1] 3

# UTF-16 with and without a byte-order mark
le <- as.raw(c(0xff, 0xfe, 0x61, 0x00, 0x00, 0xd8))
utf_valid(le, "UTF-16")                     # the BOM says little-endian
#> [1] FALSE
utf_error_at(le, "UTF-16LE")                # unpaired surrogate, unit 2
#> [1] 2

# several byte strings at once
utf_valid(list(charToRaw("ok"), as.raw(0xc0), NULL))
#> [1]  TRUE FALSE    NA

utf_is_ascii(c("abc", "café"))
#> [1]  TRUE FALSE
```
