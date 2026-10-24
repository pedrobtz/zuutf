# Encode and decode Base64

`base64_encode()` writes bytes as Base64 text; `base64_decode()` reads
it back.

## Usage

``` r
base64_encode(x, url = FALSE, pad = TRUE, line_length = NULL)

base64_decode(x, url = FALSE, forgiving = TRUE)
```

## Arguments

- x:

  For `base64_encode()`, a raw vector, or a single string, which is
  encoded as its UTF-8 bytes. For `base64_decode()`, a single string or
  a raw vector holding the Base64 text.

- url:

  Which alphabet: `FALSE` (the default) for the standard one with `+`
  and `/`, `TRUE` for the URL- and filename-safe one with `-` and `_`.
  `base64_decode()` also takes `NA`, which accepts either.

- pad:

  Whether `base64_encode()` writes `=` padding.

- line_length:

  `NULL` (the default) for one line, or a whole number of at least 4,
  one Base64 quantum: a line feed (`"\n"`) is written after every
  `line_length` characters, as MIME and PEM do with 76 and 64. A value
  at least as long as the text gives one line. For the CRLF of MIME, use
  [`gsub()`](https://rdrr.io/r/base/grep.html) on the result.

- forgiving:

  `TRUE` (the default) for WHATWG forgiving decoding, `FALSE` for strict
  RFC 4648; see Details.

## Value

`base64_encode()`: a single string. `base64_decode()`: a raw vector.
Input the chosen mode rejects raises a `zuutf_base64_error` whose
`offset` is the 1-based position of the offending character.

## Details

Decoding is forgiving by default, as the WHATWG "forgiving-base64
decode" is: ASCII whitespace (space, tab, line feed, form feed, carriage
return) is skipped, padding is optional, and a final quantum of a single
character is an error. `forgiving = FALSE` reads RFC 4648 section 3.3
strictly: padding is required, the unused bits of the last character
must be zero, and whitespace is an error too. Padding is required with
the URL alphabet as well, so text written with `pad = FALSE` decodes
only in forgiving mode.

## See also

[zuutf_error](https://pedrobtz.github.io/zuutf/reference/zuutf_error.md)
for the condition classes.

## Examples

``` r
base64_encode(charToRaw("hello"))
#> [1] "aGVsbG8="
base64_encode("hello", pad = FALSE)
#> [1] "aGVsbG8"
base64_encode(as.raw(c(0xfb, 0xff)), url = TRUE)
#> [1] "-_8="
base64_encode(as.raw(0:59), line_length = 64)
#> [1] "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gISIjJCUmJygpKissLS4v\nMDEyMzQ1Njc4OTo7"

rawToChar(base64_decode("aGVsbG8="))
#> [1] "hello"
base64_decode(" aGVs bG8 ")              # whitespace is skipped
#> [1] 68 65 6c 6c 6f
base64_decode("-_8", url = TRUE)
#> [1] fb ff
base64_decode("+/8", url = NA)           # either alphabet
#> [1] fb ff
tryCatch(
  base64_decode("aGVsbG8", forgiving = FALSE),   # padding is required
  zuutf_base64_error = function(e) e$offset
)
#> [1] 7
```
