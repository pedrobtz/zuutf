
# zuutf

<!-- badges: start -->
[![R-CMD-check](https://github.com/pedrobtz/zuutf/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/pedrobtz/zuutf/actions/workflows/R-CMD-check.yaml)
[![coverage](https://raw.githubusercontent.com/pedrobtz/zuutf/gh-pages/badges/coverage.svg)](https://github.com/pedrobtz/zuutf/actions/workflows/coverage.yaml)
<!-- badges: end -->

Every Unicode encoding R meets, validated and converted at memory speed,
with the exact position of the first error.

zuutf validates text and converts it between UTF-8, UTF-16 (LE and BE),
UTF-32 (LE and BE) and Latin-1, counts characters, detects encodings, and
encodes and decodes Base64. It does this with a bundled copy of
[simdutf](https://github.com/simdutf/simdutf), which picks SIMD code for
the processor at first use. Other packages can call the same functions
from C through a registered table (`vignette("linking")`).

## Installation

``` r
install.packages("zuutf")
```

The development version is on GitHub:

``` r
# install.packages("pak")
pak::pak("pedrobtz/zuutf")
```

## Validation, with the position of the first error

``` r
library(zuutf)

utf_valid(c("plain", "café", NA))
#> [1]  TRUE  TRUE    NA

bad <- as.raw(c(0x61, 0x62, 0xe2, 0x82, 0x63))   # a truncated euro sign
utf_valid(bad)
#> [1] FALSE
utf_error_at(bad)
#> [1] 3
```

## UTF-16 from Windows tools

``` r
bytes <- readBin("export.csv", "raw", file.size("export.csv"))
utf_detect(bytes)                 # the byte-order mark decides
#> [1] "UTF-16LE"
text <- utf_decode(bytes)         # from = "auto"; the BOM is dropped
```

Ill-formed input raises a classed error by default; `invalid = "replace"`
writes U+FFFD as web browsers do, and `invalid = "na"` gives `NA`:

``` r
utf_decode(as.raw(c(0x61, 0xff, 0x62)), "UTF-8", invalid = "replace")
#> [1] "a�b"
```

## Base64

``` r
s <- base64_encode(charToRaw("hello, world"))
s
#> [1] "aGVsbG8sIHdvcmxk"
rawToChar(base64_decode(s))
#> [1] "hello, world"
base64_encode(as.raw(0:63), url = TRUE, pad = FALSE)
```

Decoding is forgiving by default, as browsers' is; `forgiving = FALSE`
reads RFC 4648 strictly.

## Learn more

- `vignette("zuutf")`: encodings, error policies and offsets.
- `vignette("linking")`: calling zuutf from another package's C code.
- `zuutf_info()`: the simdutf version and the kernel in use.
