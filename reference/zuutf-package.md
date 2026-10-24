# zuutf: Fast Unicode validation and transcoding with simdutf

Validates text and converts it between UTF-8, UTF-16 and UTF-32 in
either byte order and Latin-1, counts characters, detects encodings, and
encodes and decodes Base64, through a bundled copy of the simdutf
library. Every validation and conversion can report the position of the
first ill-formed sequence, in the units of the input.

## See also

Useful links:

- <https://github.com/pedrobtz/zuutf>

- <https://pedrobtz.github.io/zuutf/>

- Report bugs at <https://github.com/pedrobtz/zuutf/issues>

## Author

**Maintainer**: Pedro Baltazar <pedrobtz@gmail.com> \[copyright holder\]

Authors:

- Pedro Baltazar <pedrobtz@gmail.com> \[copyright holder\]

Other contributors:

- Daniel Lemire (simdutf, bundled in src/vendor/simdutf) \[contributor,
  copyright holder\]

- The simdutf authors (simdutf, bundled in src/vendor/simdutf)
  \[copyright holder\]

- Facebook, Inc (CPU detection in src/vendor/simdutf/simdutf.h, from
  PyTorch) \[copyright holder\]

- Idiap Research Institute (CPU detection in
  src/vendor/simdutf/simdutf.h, from PyTorch) \[copyright holder\]

- Deepmind Technologies (CPU detection in src/vendor/simdutf/simdutf.h,
  from PyTorch) \[copyright holder\]

- NEC Laboratories America (CPU detection in
  src/vendor/simdutf/simdutf.h, from PyTorch) \[copyright holder\]

- NYU (CPU detection in src/vendor/simdutf/simdutf.h, from PyTorch)
  \[copyright holder\]

- Adam Paszke (PyTorch CPU detection, in src/vendor/simdutf/simdutf.h)
  \[contributor\]

- Soumith Chintala (PyTorch CPU detection, in
  src/vendor/simdutf/simdutf.h) \[contributor\]

- Ronan Collobert (PyTorch CPU detection, in
  src/vendor/simdutf/simdutf.h) \[contributor\]

- Koray Kavukcuoglu (PyTorch CPU detection, in
  src/vendor/simdutf/simdutf.h) \[contributor\]

- Clement Farabet (PyTorch CPU detection, in
  src/vendor/simdutf/simdutf.h) \[contributor\]

- Leon Bottou (PyTorch CPU detection, in src/vendor/simdutf/simdutf.h)
  \[contributor\]

- Iain Melvin (PyTorch CPU detection, in src/vendor/simdutf/simdutf.h)
  \[contributor\]

- Jason Weston (PyTorch CPU detection, in src/vendor/simdutf/simdutf.h)
  \[contributor\]

- Samy Bengio (PyTorch CPU detection, in src/vendor/simdutf/simdutf.h)
  \[contributor\]

- Johnny Mariethoz (PyTorch CPU detection, in
  src/vendor/simdutf/simdutf.h) \[contributor\]

- Markus Kuhn (UTF-8 stress test,
  tests/testthat/fixtures/UTF-8-test.txt) \[copyright holder\]

- web-platform-tests contributors (Base64 vectors,
  tests/testthat/fixtures/whatwg-base64.tsv) \[copyright holder\]
