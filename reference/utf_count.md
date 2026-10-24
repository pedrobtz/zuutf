# Count code points and conversion lengths

`utf_count()` counts the code points (characters, in the sense of
`nchar(type = "chars")`) of each element. `utf_length_as()` gives the
number of bytes converting each element from `from` to `to` will
produce, without converting it.

## Usage

``` r
utf_count(x, encoding = "UTF-8", useBytes = FALSE)

utf_length_as(x, from = "UTF-8", to)
```

## Arguments

- x:

  A character vector, a raw vector (one element), or a list of raw
  vectors (one element each). `NA` strings and `NULL` list elements give
  `NA`.

- encoding, from:

  The encoding of the input: `"UTF-8"`, `"UTF-16LE"`, `"UTF-16BE"`,
  `"UTF-16"`, `"UTF-32LE"`, `"UTF-32BE"`, `"UTF-32"` or `"Latin-1"`,
  matched without regard to case or hyphens; `utf_count()` also takes
  `"ASCII"`. A character vector is UTF-8 text, so for one only `"UTF-8"`
  applies, and `"ASCII"` in `utf_count()`, unless `useBytes = TRUE` in
  `utf_count()`.

- useBytes:

  For a character vector: `FALSE` (the default) takes each string in its
  marked encoding and checks its UTF-8 form, refusing strings marked
  `"bytes"`; `TRUE` checks the bytes of every string as they are, which
  is how to check a string R believes is UTF-8.

- to:

  The target encoding: `"UTF-8"`, `"UTF-16LE"`, `"UTF-16BE"`,
  `"UTF-32LE"`, `"UTF-32BE"` or `"Latin-1"`.

## Value

An integer vector, one value per element, `NA` where the element is
`NA`, `NULL` or ill-formed. Counts beyond the integer range come back as
doubles. A character vector or a list keeps its names.

## Details

A leading byte-order mark that matches the input encoding is skipped and
not counted, and a conversion writes none, so neither counts it. An
element that is ill-formed in its encoding gives `NA`;
[utf_error_at()](https://pedrobtz.github.io/zuutf/reference/utf_valid.md)
says where. With a `"Latin-1"` target every code point is one byte,
those above U+00FF included, since a conversion writes one byte for each
of them too (an error, `?` or `NA`, as its `invalid` argument says).

## See also

[`utf_valid()`](https://pedrobtz.github.io/zuutf/reference/utf_valid.md);
[`nchar()`](https://rdrr.io/r/base/nchar.html).

## Examples

``` r
utf_count(c("abc", "caf\u00e9", "\U0001f600", NA))
#> [1]  3  4  1 NA
utf_count(as.raw(c(0x3d, 0xd8, 0x00, 0xde)), "UTF-16LE")   # one emoji
#> [1] 1

utf_length_as("caf\u00e9", to = "UTF-16LE")   # 8 bytes
#> [1] 8
utf_length_as("\U0001f600", to = "UTF-16LE")  # a surrogate pair: 4 bytes
#> [1] 4
utf_length_as(as.raw(c(0x63, 0xe9)), from = "Latin-1", to = "UTF-8")
#> [1] 3
```
