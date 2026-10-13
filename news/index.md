# Changelog

## zuutf 0.0.0.9000

- Bundles simdutf 9.2.1, unmodified, with every kernel it offers and the
  scalar `fallback` kernel on every platform.
- [`zuutf_info()`](https://pedrobtz.github.io/zuutf/reference/zuutf_info.md)
  reports the simdutf version, the kernel in use and the kernels
  compiled in.
- [`utf_valid()`](https://pedrobtz.github.io/zuutf/reference/utf_valid.md),
  [`utf_error_at()`](https://pedrobtz.github.io/zuutf/reference/utf_valid.md)
  and
  [`utf_is_ascii()`](https://pedrobtz.github.io/zuutf/reference/utf_valid.md)
  validate character, raw and list-of-raw input in UTF-8, UTF-16, UTF-32
  (either byte order, or chosen by a byte-order mark), Latin-1 and
  ASCII, and give the offset of the first error in the input’s code
  units.
- [`utf_count()`](https://pedrobtz.github.io/zuutf/reference/utf_count.md)
  counts code points and
  [`utf_length_as()`](https://pedrobtz.github.io/zuutf/reference/utf_count.md)
  gives the bytes a conversion will produce.
- Errors are classed conditions under `zuutf_error`
  ([`?zuutf_error`](https://pedrobtz.github.io/zuutf/reference/zuutf_error.md)).
- [`utf_convert()`](https://pedrobtz.github.io/zuutf/reference/utf_convert.md),
  [`utf_decode()`](https://pedrobtz.github.io/zuutf/reference/utf_convert.md)
  and
  [`utf_encode()`](https://pedrobtz.github.io/zuutf/reference/utf_convert.md)
  convert between every pair of UTF-8, UTF-16, UTF-32 (either byte
  order) and Latin-1, with a byte-order mark read on input and never
  written. Ill-formed input raises an error, is replaced with U+FFFD as
  the WHATWG decoder does (`?` in Latin-1), or gives `NA`, as `invalid`
  says.
- [`utf_detect()`](https://pedrobtz.github.io/zuutf/reference/utf_detect.md)
  lists the encodings bytes could be in, a byte-order mark first;
  [`utf_decode()`](https://pedrobtz.github.io/zuutf/reference/utf_convert.md)
  uses it by default.
- [`base64_encode()`](https://pedrobtz.github.io/zuutf/reference/base64_encode.md)
  and
  [`base64_decode()`](https://pedrobtz.github.io/zuutf/reference/base64_encode.md)
  cover the standard and URL alphabets (either at once on decode with
  `url = NA`), padding on or off, line wrapping, and forgiving (WHATWG)
  or strict (RFC 4648) decoding.
- A registered C table, `zuutf_api_v1`, in the installed header
  `zuutf.h`, gives other packages validation, conversion and Base64 from
  their own C code
  ([`vignette("linking")`](https://pedrobtz.github.io/zuutf/articles/linking.md)).
