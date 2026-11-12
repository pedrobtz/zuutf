# Assurance

How this package meets `.claude/shared/assurance.md`. CI checks this
file (r-actions `assurance.yml`), so keep the headings and table
columns as they are.

- **Statuses:** a cell is a fact, `gap #<issue>` or `n/a: <reason>`.
- **Kinds:** `lifecycle` does not apply: every result is an ordinary R
  vector, and the package keeps no external pointer, ALTREP vector,
  connection or handle past the call. So there is no Objects table.

## Kinds

`compiled` `untrusted-input` `spec` `emits`

## Required checks

`Where` names the workflow file under `.github/workflows/` that runs the
check. Add `(own)` when that workflow is the package's own rather than a
call to r-actions.

| Check         | Status  | Where              |
| ------------- | ------- | ------------------ |
| sanitizers    | done    | native-checks.yaml |
| valgrind      | done    | native-checks.yaml |
| rchk          | done    | native-checks.yaml |
| gctorture     | done    | native-checks.yaml |
| analyzers     | done    | native-checks.yaml |
| alloc-failure | gap #64 |                    |
| mutation      | gap #65 |                    |
| fuzz          | done    | hardening.yaml     |
| fuzz-reach    | gap #66 | hardening.yaml     |

## Boundaries

One row per boundary the package crosses. An oracle knows the answer:

- a conformance suite or test vectors;
- a reference implementation;
- a round trip;
- equivalent inputs compared;
- the bytes the other side received.

"No crash" is not an oracle.

<!-- markdownlint-disable MD013 -->
| Boundary | Oracle | Carried by |
| --- | --- | --- |
| UTF-8 validation and error offsets | Markus Kuhn's stress test and 10,000 random byte strings against `validUTF8()`, under every kernel; zufast's independent scalar validator on the corpus, every truncation of the stress test, random strings and the unicode_lipsum samples; each malformed class and a bad byte at every position found at the offset the test planted | tests/testthat/test-validate.R, test-kernels.R, test-hostile.R; tools/zuutforacle (hardening.yaml `oracle`, every kernel) |
| UTF-16LE/BE and UTF-32LE/BE decoding | `iconv()` byte for byte wherever it succeeds; the unicode_lipsum UTF-16 and UTF-32 samples against their UTF-8; files Windows PowerShell wrote; a bad unit at every position found where it was planted | tests/testthat/test-convert.R, test-hostile.R; tools/zuutforacle |
| Latin-1 and ASCII decoding | `iconv()` byte for byte; ASCII stops at 0x80 and Latin-1 is total, by construction | tests/testthat/test-convert.R, test-validate.R |
| Encoding to UTF-8, UTF-16, UTF-32 and Latin-1 | `iconv()` byte for byte; every pair round-trips; the Latin-1 edge between U+00FF and U+0100; the fuzz target's round trip | tests/testthat/test-convert.R; tools/fuzz/fuzz_convert.c |
| Replacement of ill-formed input (U+FFFD) | the WHATWG decoder's output on the stress test (`UTF-8-test.whatwg.txt`, from `TextDecoder`); simdutf's own replacement on UTF-16; the three policies in every source encoding | tests/testthat/test-convert.R |
| Byte-order mark and encoding detection | the design §6 vectors: a BOM alone, a BOM cut short, then the stated order; PowerShell files with a BOM | tests/testthat/test-convert.R, test-hostile.R; tools/zuutforacle |
| Character input in its marked encoding | hand vectors: a Latin-1 `café` is valid and counts 4 once converted, a bytes-marked string is refused unless `useBytes = TRUE`, and `useBytes` reads UTF-16 bytes as they are | tests/testthat/test-validate.R |
| Code point and unit counts | `nchar()` on valid text; `utf_length_as()` against the length the conversion produces; the fuzz target's UTF-32 length of 4 × count | tests/testthat/test-count.R; tools/fuzz/fuzz_validate.c |
| Base64 strict decoding, both alphabets | RFC 4648 §10 vectors; zufast's strict decoder accepts exactly what zuutf accepts; every byte value in every position; the fuzz target's re-encode | tests/testthat/test-base64.R; tools/zuutforacle; tools/fuzz/fuzz_base64.c |
| Base64 forgiving decoding | web-platform-tests' forgiving-base64 vectors, with the error offset | tests/testthat/test-base64.R |
| Base64 encoding, both alphabets, padded or not, with lines | RFC 4648 §10 vectors; `base64enc` byte for byte with and without line breaks; round trips under every alphabet and padding; zufast decodes what zuutf writes | tests/testthat/test-base64.R; tools/zuutforacle; tools/fuzz/fuzz_base64.c |
| The C table `zuutf_api_v1` | zufast on a million random strings through the C table; a consumer package built against the installed header | tools/zuutforacle; tools/zuutftest (consumer.yaml) |
<!-- markdownlint-enable MD013 -->

## Limits

One row per limit the package enforces. "Straddled by" is the test of
`limit - 1`, `limit` and `limit + 1` on every path that reaches it.

<!-- markdownlint-disable MD013 -->
| Limit | Unit | Straddled by |
| --- | --- | --- |
| `line_length` at least 4 | characters | tests/testthat/test-base64.R: 3 refused, 4 against `base64enc` |
| `line_length` at or past the text's length gives one line | characters | tests/testthat/test-base64.R: the text's length, 76 for 57 bytes against `base64enc`, and past it |
| Base64 text at most `INT_MAX` characters (`zuutf_size_error`) | output characters | gap #67 |
| A converted string at most 2^31 - 1 bytes (`utf_convert()` to character, `utf_decode()`) | output bytes | gap #68 |
| A converted raw vector at most `R_XLEN_T_MAX` bytes | output bytes | n/a: unreachable, the input would need 2^50 bytes or more |
<!-- markdownlint-enable MD013 -->
