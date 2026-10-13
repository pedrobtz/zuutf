# Conditions raised by zuutf

Every error zuutf raises inherits from `zuutf_error`, then `error` and
`condition`, so a caller can catch all of them, or one kind, with
[`tryCatch()`](https://rdrr.io/r/base/conditions.html). Test code should
match on the class, never on the message.

## Details

|  |  |  |
|----|----|----|
| Class | Fields | Raised when |
| `zuutf_invalid_argument` |  | wrong type, unknown encoding name, a `"bytes"` string without `useBytes` |
| `zuutf_encoding_error` | `index`, `offset`, `encoding` | input that is ill-formed in its encoding under `invalid = "error"`, or a code point a Latin-1 target cannot represent |
| `zuutf_nul_error` | `index`, `offset` | [`utf_decode()`](https://pedrobtz.github.io/zuutf/reference/utf_convert.md) meets U+0000, which an R string cannot hold |
| `zuutf_base64_error` | `offset` | Base64 input that [`base64_decode()`](https://pedrobtz.github.io/zuutf/reference/base64_encode.md)'s mode rejects |
| `zuutf_size_error` |  | an output longer than a string (2^31 - 1 bytes) or a raw vector can hold |
| `zuutf_internal_error` |  | a simdutf result zuutf did not expect, or a kernel forced through `SIMDUTF_FORCE_IMPLEMENTATION` that this processor cannot run |

`index` is the 1-based element of the input, `offset` the 1-based
position of the first error in the input's code units (bytes for UTF-8,
Latin-1 and ASCII; 16-bit units for UTF-16; 32-bit units for UTF-32),
counted after any byte-order mark, and `encoding` the name of the
encoding.

## Examples

``` r
tryCatch(
  utf_valid("abc", encoding = "EBCDIC"),
  zuutf_invalid_argument = function(e) class(e)
)
#> [1] "zuutf_invalid_argument" "zuutf_error"            "error"                 
#> [4] "condition"             
```
