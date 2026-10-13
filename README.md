
# zuutf

<!-- badges: start -->
[![R-CMD-check](https://github.com/pedrobtz/zuutf/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/pedrobtz/zuutf/actions/workflows/R-CMD-check.yaml)
[![coverage](https://raw.githubusercontent.com/pedrobtz/zuutf/gh-pages/badges/coverage.svg)](https://github.com/pedrobtz/zuutf/actions/workflows/coverage.yaml)
<!-- badges: end -->

Every Unicode encoding R meets, validated and converted at memory speed,
with the exact position of the first error.

zuutf validates text and converts it between UTF-8, UTF-16 (LE and BE),
UTF-32 (LE and BE) and Latin-1, counts characters, detects encodings, and
encodes and decodes Base64. It does this through a bundled copy of
[simdutf](https://github.com/simdutf/simdutf), which picks SIMD code for
the running processor at first use. Other packages can call the same
functions from C through a registered table.

zuutf is in development. Nothing is exported yet; the plan to the first
release is in [`.agents/roadmap.md`](https://github.com/pedrobtz/zuutf/blob/main/.agents/roadmap.md).

## Installation

You can install the development version of zuutf from
[GitHub](https://github.com/pedrobtz/zuutf) with:

``` r
# install.packages("pak")
pak::pak("pedrobtz/zuutf")
```
