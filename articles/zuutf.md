# Encodings, errors and offsets

``` r

library(zuutf)
```

zuutf validates and converts text between UTF-8, UTF-16, UTF-32 and
Latin-1 with the simdutf library, and says where the first error is.
This vignette covers what it accepts, what it does with bad input, and
how it counts positions.

## Three shapes of input

Every function takes a character vector, a raw vector or a list of raw
vectors. A raw vector is one element; a list holds one element per raw
vector, and `NULL` is a missing one.

``` r

utf_valid(c("plain", "caf\u00e9", NA))
#> [1] TRUE TRUE   NA
utf_valid(as.raw(c(0x61, 0xff)))
#> [1] FALSE
utf_valid(list(charToRaw("ok"), as.raw(0xc0), NULL))
#> [1]  TRUE FALSE    NA
```

A character vector is text: each string is taken in its marked encoding
and checked in its UTF-8 form. To check the bytes R holds instead, use
`useBytes = TRUE`.

## Encodings

The names are `"UTF-8"`, `"UTF-16LE"`, `"UTF-16BE"`, `"UTF-32LE"`,
`"UTF-32BE"` and `"Latin-1"`, matched without regard to case or hyphens.
`"ASCII"` is for validation. On input, `"UTF-16"` and `"UTF-32"` let a
byte-order mark choose, big-endian without one, and
[`utf_decode()`](https://pedrobtz.github.io/zuutf/reference/utf_convert.md)
defaults to `"auto"`, which asks
[`utf_detect()`](https://pedrobtz.github.io/zuutf/reference/utf_detect.md).

``` r

le <- utf_encode("na\u00efve", "UTF-16LE")
le
#>  [1] 6e 00 61 00 ef 00 76 00 65 00
utf_detect(le)
#> [1] "UTF-16LE" "UTF-16BE"
utf_decode(c(as.raw(c(0xff, 0xfe)), le))      # the BOM says little-endian
#> [1] "naïve"
utf_decode(le, "UTF-16LE")
#> [1] "naïve"
```

A leading byte-order mark that matches the input encoding is dropped,
and no output carries one.

## What happens to bad input

`invalid` chooses: an error, a replacement, or a missing value.

``` r

bad <- as.raw(c(0x61, 0xe2, 0x82, 0x62))      # "a", a cut-short euro sign, "b"
utf_decode(bad, "UTF-8", invalid = "replace")
#> [1] "a�b"
utf_decode(bad, "UTF-8", invalid = "na")
#> [1] NA
e <- tryCatch(utf_decode(bad, "UTF-8"), zuutf_encoding_error = function(e) e)
class(e)
#> [1] "zuutf_encoding_error" "zuutf_error"          "error"               
#> [4] "condition"
e$index
#> [1] 1
e$offset
#> [1] 2
e$encoding
#> [1] "UTF-8"
```

`"replace"` writes one U+FFFD for each maximal ill-formed subpart, as
web browsers do, so the two bytes of the cut-short sequence above become
one replacement character. In a Latin-1 target, which has no U+FFFD, it
writes `?`, and code points above U+00FF count as invalid too:

``` r

utf_encode("\u00e9t\u00e9 \u2600", "Latin-1", invalid = "replace")
#> [1] e9 74 e9 20 3f
```

R strings cannot hold U+0000, so decoding one to a string is an error
under every policy.
[`utf_convert()`](https://pedrobtz.github.io/zuutf/reference/utf_convert.md)
keeps it:

``` r

nul <- as.raw(c(0x61, 0x00, 0x62))
tryCatch(utf_decode(nul, "UTF-8"), zuutf_nul_error = function(e) e$offset)
#> [1] 2
utf_convert(nul, "UTF-8", "UTF-16LE")
#> [1] 61 00 00 00 62 00
```

## Offsets

Offsets are 1-based, in the code units of the input: bytes for UTF-8 and
Latin-1, 16-bit units for UTF-16, 32-bit units for UTF-32. They count
from after any byte-order mark.

``` r

utf_error_at(as.raw(c(0x61, 0x62, 0xff)))
#> [1] 3
u16 <- c(as.raw(c(0xff, 0xfe)), utf_encode("ab", "UTF-16LE"), as.raw(c(0x00, 0xdc)))
utf_error_at(u16, "UTF-16")       # the lone surrogate is the third unit
#> [1] 3
```

## Counting before converting

[`utf_count()`](https://pedrobtz.github.io/zuutf/reference/utf_count.md)
counts code points, as `nchar(type = "chars")` does, and
[`utf_length_as()`](https://pedrobtz.github.io/zuutf/reference/utf_count.md)
says how many bytes a conversion will write:

``` r

x <- c("abc", "\u4e2d\u6587", "\U0001f600")
utf_count(x)
#> [1] 3 2 1
nchar(x)
#> [1] 3 2 1
utf_length_as(x, to = "UTF-16LE")
#> [1] 6 4 4
```

## Base64

[`base64_encode()`](https://pedrobtz.github.io/zuutf/reference/base64_encode.md)
and
[`base64_decode()`](https://pedrobtz.github.io/zuutf/reference/base64_encode.md)
work on one raw vector or one string. Decoding is forgiving by default,
as browsers’ is; `forgiving = FALSE` reads RFC 4648 strictly.

``` r

s <- base64_encode(charToRaw("hello, world"))
s
#> [1] "aGVsbG8sIHdvcmxk"
rawToChar(base64_decode(s))
#> [1] "hello, world"
rawToChar(base64_decode(" aGVs\nbG8 "))
#> [1] "hello"
tryCatch(base64_decode("aGVsbG8", forgiving = FALSE),
         zuutf_base64_error = function(e) e$offset)
#> [1] 7
```

## Which kernel ran

simdutf picks code for the processor at first use.
[`zuutf_info()`](https://pedrobtz.github.io/zuutf/reference/zuutf_info.md)
says which:

``` r

zuutf_info()$kernel
#> [1] "icelake"
```
