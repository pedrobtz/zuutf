# zuutf 0.1.0

First release. zuutf validates and converts text between the Unicode
encodings R meets, through a bundled copy of simdutf 9.2.1, and says where
the first error is.

## Validation and counts

* `utf_valid()`, `utf_error_at()` and `utf_is_ascii()` check character, raw
  and list-of-raw input in UTF-8, UTF-16, UTF-32 (either byte order, or
  chosen by a byte-order mark), Latin-1 and ASCII, and give the 1-based
  offset of the first error in the input's code units.
* `utf_count()` counts code points; `utf_length_as()` gives the bytes a
  conversion will write.

## Conversion

* `utf_convert()`, `utf_decode()` and `utf_encode()` convert between every
  pair of UTF-8, UTF-16LE/BE, UTF-32LE/BE and Latin-1. A byte-order mark is
  read on input and never written. Ill-formed input raises an error, is
  replaced with U+FFFD as the WHATWG decoder does (`?` in Latin-1), or gives
  `NA`, as `invalid` says.
* `utf_detect()` lists the encodings bytes could be in, a byte-order mark
  first; `utf_decode()` uses it by default.

## Base64

* `base64_encode()` and `base64_decode()` cover the standard and URL
  alphabets (either at once on decode with `url = NA`), padding, line
  wrapping, and forgiving (WHATWG) or strict (RFC 4648) decoding.

## For other packages

* A registered C table, `zuutf_api_v1`, declared in the installed header
  `zuutf.h`, gives validation, conversion and Base64 to other packages' C
  code without vendoring simdutf (`vignette("linking")`).

## Errors and information

* Every error is a classed condition under `zuutf_error` (`?zuutf_error`).
* `zuutf_info()` reports the simdutf version, the kernel in use and the
  kernels compiled in.
