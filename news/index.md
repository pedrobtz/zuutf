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
