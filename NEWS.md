# zuutf 0.0.0.9000

* Bundles simdutf 9.2.1, unmodified, with every kernel it offers and the
  scalar `fallback` kernel on every platform.
* `zuutf_info()` reports the simdutf version, the kernel in use and the
  kernels compiled in.
* `utf_valid()`, `utf_error_at()` and `utf_is_ascii()` validate character,
  raw and list-of-raw input in UTF-8, UTF-16, UTF-32 (either byte order, or
  chosen by a byte-order mark), Latin-1 and ASCII, and give the offset of
  the first error in the input's code units.
* `utf_count()` counts code points and `utf_length_as()` gives the bytes a
  conversion will produce.
* Errors are classed conditions under `zuutf_error` (`?zuutf_error`).
