# zuutf: roadmap

Status: draft 2026-10-13. Implements [design.md](design.md).
Target: v0.1.0, the first CRAN release.
Tracking: [v0.1.0 (#1)](https://github.com/pedrobtz/zuutf/issues/1), with one sub-issue per
stage; [CRAN-submission (#10)](https://github.com/pedrobtz/zuutf/issues/10).

Where the package stands on 2026-10-13: a `usethis` skeleton (placeholder
`DESCRIPTION`, an empty `src/zuutf.c`, one placeholder test), the
`R-CMD-check`, `coverage` and `pkgdown` workflows, a pkgdown site, and the
adopted design. Nothing of simdutf is vendored and no function exists.

Sizes are relative: **S** is a sitting, **M** a few. A stage is done when
its exit criteria hold in CI on every r-actions leg, not when the code is
written. Sections marked § are in design.md.

## Stages

| Stage | Title | Issue | Pull request | Done |
| --- | --- | --- | --- | --- |
| 0 | [Package identity](#stage-0--package-identity) | [#2](https://github.com/pedrobtz/zuutf/issues/2) | [#12](https://github.com/pedrobtz/zuutf/pull/12) | 2026-10-13 |
| 1 | [Vendor simdutf and the Windows go/no-go](#stage-1--vendor-simdutf-and-the-windows-gono-go) | [#3](https://github.com/pedrobtz/zuutf/issues/3) | [#14](https://github.com/pedrobtz/zuutf/pull/14) | 2026-10-13 |
| 2 | [Validation, counts and kernel reporting](#stage-2--validation-counts-and-kernel-reporting) | [#4](https://github.com/pedrobtz/zuutf/issues/4) | [#15](https://github.com/pedrobtz/zuutf/pull/15) | 2026-10-13 |
| 3 | [Conversion](#stage-3--conversion) | [#5](https://github.com/pedrobtz/zuutf/issues/5) | | |
| 4 | [Base64](#stage-4--base64) | [#6](https://github.com/pedrobtz/zuutf/issues/6) | | |
| 5 | [The C table and the consumer fixture](#stage-5--the-c-table-and-the-consumer-fixture) | [#7](https://github.com/pedrobtz/zuutf/issues/7) | | |
| 6 | [Oracles, hostile input, fuzzing and benchmarks](#stage-6--oracles-hostile-input-fuzzing-and-benchmarks) | [#8](https://github.com/pedrobtz/zuutf/issues/8) | | |
| 7 | [v0.1.0 readiness](#stage-7--v010-readiness) | [#9](https://github.com/pedrobtz/zuutf/issues/9) | | |

## Stage 0 — Package identity

**Issue.** [#2](https://github.com/pedrobtz/zuutf/issues/2), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zuutf/issues/1).

**Goal.** The repository says what the package is, carries the family's
`DESCRIPTION` fields and `CLAUDE.md`, and `R CMD check` is green on every
r-actions leg before any simdutf code arrives. Size: S.

**Work.**
- `DESCRIPTION`: real `Title`, `Description` (naming simdutf and what it
  does), `Authors@R` with `cre`/`aut` for the maintainer and `cph` for
  Daniel Lemire and the simdutf contributors, `Depends: R (>= 4.1)`,
  `Language: en-GB`, `SystemRequirements: C++17`, `URL` and `BugReports`,
  `Suggests: testthat (>= 3.0.0), withr` (§3).
- `LICENSE` and `LICENSE.md` for zuutf's MIT; `LICENSE.note` naming
  simdutf's MIT option (§8).
- `.claude/CLAUDE.md` from `templates/package-CLAUDE.md` in
  `pedrobtz/packages` (alignment R8), pointing at design.md as the
  specification and at this roadmap.
- `R/zuutf-package.R` with the package documentation; `README.md` with the
  one-line statement and the installation block; the placeholder test
  replaced by a test that the namespace loads.
- `.Rbuildignore` covers `.agents`, `.claude`, `.github`, `tools`,
  `_pkgdown.yml`, `pkgdown`, `docs`, `cran-comments.md`.
- `R-CMD-check.yaml` stays on `r-cmd-check.yml@v1` with the quick profile on
  pull requests and the full profile on `main` and the `full-ci` label
  (R5); the stage label and the tracking issues of this roadmap exist.

**Exit criteria.**
- `R CMD check --as-cran` passes on every r-actions leg of the full profile
  with no `NOTE` other than "New submission".
- `spelling::spell_check_package()` is clean with `inst/WORDLIST`.
- `DESCRIPTION` carries every field §3 lists, and `Version: 0.0.0.9000`.
- `.claude/CLAUDE.md` exists and links design.md and roadmap.md.

**Design.** §1, §3, §8 (licence), §12.2 (workflow set).

## Stage 1 — Vendor simdutf and the Windows go/no-go

**Issue.** [#3](https://github.com/pedrobtz/zuutf/issues/3), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zuutf/issues/1).

**Goal.** simdutf v9.2.1 is in the tree with its manifest, compiles under
CRAN's flags on every leg including Rtools, and the §12.1 question is
answered with numbers. Nothing user-facing exists yet; one internal
function proves the kernels work. Size: M.

**Work.**
- `tools/vendor/manifest.tsv`, `checksums.sha256` and the `fetch`, `apply`
  and `verify` scripts in zucrypt's shape; `src/vendor/simdutf/simdutf.h`,
  `simdutf.cpp`, `simdutf_c.h` from the `v9.2.1` `singleheader.zip`, SHA-256
  as recorded in §8; `inst/COPYRIGHTS` (§8).
- `src/Makevars` and `Makevars.win`: `CXX_STD = CXX17`,
  `PKG_CXXFLAGS = $(CXX_VISIBILITY)`, `PKG_CFLAGS = $(C_VISIBILITY)`,
  `PKG_CPPFLAGS = -Isrc/vendor/simdutf` (§12.2).
- `src/zut_impl.cpp`, the `extern "C"` shim: active kernel name, the list
  of compiled kernels with whether the CPU supports each, and
  `zut_force_kernel()` (§4, D10).
- An internal `.zut_probe(raw)` that validates UTF-8 through the C API, and
  `zuutf_info()` reporting the simdutf version, the kernels compiled in and
  the kernel in use (§5, §12.1).
- Workflows: `vendor.yaml` (`vendor.yml@v1`, running `tools/vendor/verify`),
  `native-checks.yaml` (sanitizers, valgrind, gctorture, rchk, lto, as
  zudedup's), and a `kernel-matrix` job that runs the test suite once per
  kernel the runner supports with `SIMDUTF_FORCE_IMPLEMENTATION` set before
  R starts and asserts `zuutf_info()$kernel` equals it (§10).
- `test-abi.R`: the installed shared object exports `R_init_zuutf` and, on
  Linux with GCC, libstdc++ template instantiations only (§12.2, R3).
- `test-vendor.R`: the installed object references none of `printf`,
  `abort`, `exit`, `stderr` (§8).
- §12.1 **Outcome** and §12.2 measurements (compile time, object size,
  export count on each leg) written into design.md in this pull request.
  If a kernel fails under Rtools, `Makevars.win` carries its
  `SIMDUTF_IMPLEMENTATION_<KERNEL>=0` switch and the outcome says which.

**Exit criteria.**
- `R CMD check --as-cran` passes on every leg, Windows included, with no
  "non-portable flags" or "compilation flags in Makevars" finding.
- `tools/vendor/verify` passes in `vendor.yaml`; the manifest's SHA-256
  matches §8.
- The `kernel-matrix` job is green on `fallback` and `westmere` on every
  x86-64 leg, `haswell` where the runner has AVX2, `icelake` where it has
  AVX-512 VBMI2, and `arm64` on macOS, with the asserted kernel name in
  each log.
- `native-checks.yaml` is green.
- `test-abi.R` and `test-vendor.R` pass on every leg.
- design.md §12.1 has an **Outcome** paragraph and §12.2 has the measured
  numbers for Linux and Windows beside the macOS ones.

**Deviations (2026-10-13).** `PKG_CPPFLAGS` is `-Ivendor/simdutf`, not
`-Isrc/vendor/simdutf`: the compiler runs inside `src/`. It also carries
`-DSIMDUTF_IMPLEMENTATION_FALLBACK=1` (design D16), so the `fallback` kernel
exists on arm64 and the kernel matrix runs it on macOS beside `arm64`.
`src/Makevars` lists `OBJECTS`, and `src/zuutf-win.def` limits the Windows
DLL's exports to `R_init_zuutf`. On Windows `test-vendor.R` allows the four
imports Rtools' statically linked C++ runtime brings (`abort`, `exit`,
`_exit`, `__acrt_iob_func`) and still fails on any other (design §8).

**Design.** §4, §8, §10 (kernel matrix), §12.

## Stage 2 — Validation, counts and kernel reporting

**Issue.** [#4](https://github.com/pedrobtz/zuutf/issues/4), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zuutf/issues/1).

**Goal.** `utf_valid()`, `utf_error_at()`, `utf_is_ascii()`, `utf_count()`
and `utf_length_as()` work on character, raw and list-of-raw input in every
encoding §5 names, and errors are classed. Size: S.

**Work.**
- The R layer's shared argument handling: input shapes, encoding-name
  matching, encoding marks and `useBytes`, `NA` and `NULL` elements (§5).
- `src/zut_validate.c`, `zut_count.c`: per-element loops over the C API's
  `validate_*_with_errors`, `count_*` and `*_length_from_*` functions, with
  `R_CheckUserInterrupt()` between elements; UTF-32BE through the byte-swap
  scratch buffer (§6, D13); 1-based offsets in the input's units (§9).
- The condition classes `zuutf_error`, `zuutf_invalid_argument`,
  `zuutf_encoding_error`, `zuutf_internal_error` and their constructors (§9).
- Tests against `validUTF8()` on Markus Kuhn's stress test and on every
  malformed class §6 lists; `utf_count()` against `nchar(type = "chars")`
  on valid input; offsets by hand-built cases; the first `tests/testthat/
  fixtures/MANIFEST.tsv`.
- Reference pages for every function above, with examples.

**Exit criteria.**
- Every function listed in the goal is exported, documented and tested on
  all three input shapes and on every encoding name §5 accepts.
- `utf_valid()` agrees with `validUTF8()` on every fixture and on 10,000
  random byte strings of lengths 0–200.
- `utf_error_at()` returns the offset of the first error on every hand-built
  case, in the input's units, after any BOM.
- All of Stage 1's workflows stay green, kernel matrix included.

**Design.** §5, §6, §9.

## Stage 3 — Conversion

**Issue.** [#5](https://github.com/pedrobtz/zuutf/issues/5), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zuutf/issues/1).

**Goal.** `utf_convert()`, `utf_decode()`, `utf_encode()` and
`utf_detect()` convert between every pair §2 lists under all three
`invalid` policies, with BOM handling and encoding detection. Size: M.

**Work.**
- `src/zut_convert.c`: output sized by the C API's length functions and
  allocated once as the R result; `_safe` variants wherever the C API has
  one; the replacement loop over `_with_errors` positions and
  `convert_valid_*` runs, with the maximal-subpart rule for UTF-8 (§6, D8);
  `?` for unrepresentable code points in a Latin-1 target.
- BOM stripping and `"UTF-16"`, `"UTF-32"` and `"auto"` on input; no BOM on
  output (§6).
- `utf_detect()` over the BOM first and `detect_encodings` second, with
  the §6 order (§6).
- `zuutf_nul_error` and `zuutf_size_error` (§9); NUL detection before a
  `CHARSXP` is made.
- Tests: byte-identical to `iconv()` wherever `iconv()` succeeds, on the
  corpus and on random valid input generated from random code points;
  round trips through every pair; the replacement loop against simdutf's
  own `convert_utf16*_to_utf8_with_replacement` on the corpus; WHATWG's
  replacement positions on the UTF-8 stress test; UTF-16 and UTF-32
  fixtures in both byte orders with and without BOM.

**Exit criteria.**
- Every pair of UTF-8, UTF-16LE/BE, UTF-32LE/BE and Latin-1 converts in
  both directions, and the `"error"`, `"replace"` and `"na"` policies each
  have a test per source encoding.
- Conversions match `iconv()` byte for byte on every fixture where
  `iconv()` succeeds, on every leg.
- `utf_decode()` on a sequence containing U+0000 raises `zuutf_nul_error`
  with the right offset under every policy.
- `utf_detect()` returns the BOM's encoding alone when a BOM is present,
  and the §6 order otherwise, on the fixtures.
- Kernel matrix and native checks green.

**Design.** §5, §6, §9.

## Stage 4 — Base64

**Issue.** [#6](https://github.com/pedrobtz/zuutf/issues/6), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zuutf/issues/1).

**Goal.** `base64_encode()` and `base64_decode()` cover both alphabets,
padding, forgiving and strict decoding and line wrapping. Size: S.

**Work.**
- `src/zut_base64.c` over `binary_to_base64`, `binary_to_base64_with_lines`
  and `base64_to_binary_safe`, mapping `url`, `pad` and `forgiving` to the
  `simdutf_base64_options` and last-chunk enums; the whitespace scan for
  strict mode; `zuutf_base64_error` with the offset (§6, §9, D14).
- The WHATWG forgiving-base64 test vectors and RFC 4648 test vectors as
  fixtures; round trips over random raw vectors of every length modulo 4;
  every byte value in every position of a short input.
- Decide §16 Q1 (the `base64_` prefix) and Q4 (`url = NA`) and record them
  in §15 before the functions are exported.

**Exit criteria.**
- Round trip `base64_decode(base64_encode(x))` is identical to `x` for
  10,000 random raw vectors under each alphabet and padding setting.
- Every WHATWG vector decodes or fails as the specification says with
  `forgiving = TRUE`; every strict-mode rejection (whitespace, missing
  padding, non-zero trailing bits) raises `zuutf_base64_error` with the
  offending offset.
- `line_length` output matches `base64enc::base64encode(linewidth = )` with
  `"\n"` separators on the fixtures.
- §15 records the decisions on Q1 and Q4.

**Design.** §5, §6, §9, §16.

## Stage 5 — The C table and the consumer fixture

**Issue.** [#7](https://github.com/pedrobtz/zuutf/issues/7), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zuutf/issues/1).

**Goal.** A consumer package can validate, convert and decode Base64 through
`zuutf_api_v1` without including simdutf's headers, and CI proves it. Size: S.

**Work.**
- `inst/include/zuutf.h`: `zuutf_result`, the `ZUUTF_ERR_*` codes mirrored
  from simdutf's enum with a `static_assert` in `src/` that the values
  match, the `zuutf_api` struct with `struct_size` first,
  `ZUUTF_API_HAS()` and `ZUUTF_DEFINE_API_GET` (§7).
- `src/zut_api.c`: the members, each with an explicit output capacity;
  registration in `R_init_zuutf` with `R_RegisterCCallable()` (§7, §12.2).
- `tools/zuutftest`: a fixture package with `Imports` and `LinkingTo` on
  zuutf and `importFrom(zuutf, zuutf_info)`, calling every member through
  `zuutf_api_get()`, with a frozen copy of the 0.1.0 table whose offsets
  must match the header (§7).
- `consumer.yaml`: installs the fixture with zuutf's source tree off the
  library path (R10.4); `vignette("linking")` showing the `DESCRIPTION`,
  `NAMESPACE` and C side of a consumer.

**Exit criteria.**
- `consumer.yaml` is green on every leg: the fixture builds, loads and
  calls every member with the expected results.
- The frozen-table offset check fails the fixture build when a member is
  reordered (verified once by a deliberate change on a branch, recorded in
  the pull request).
- `inst/include/zuutf.h` compiles standalone under `-Werror` in C99 and
  C++17 with no simdutf or R header included.
- `test-abi.R` still passes: registration adds no exported symbol.

**Design.** §7, §12.2.

## Stage 6 — Oracles, hostile input, fuzzing and benchmarks

**Issue.** [#8](https://github.com/pedrobtz/zuutf/issues/8), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zuutf/issues/1).

**Goal.** Every §10 gate exists and every §11 row has a measured number.
Size: M.

**Work.**
- `tools/zuutforacle`: a CI-only fixture with `LinkingTo: zufast` that runs
  zufast's `zuf_utf8_valid()`, `zuf_utf8_count()` and strict Base64 decoder
  against zuutf on every corpus file and on a million random byte strings,
  comparing results, counts and offsets (§10, D12), run by `hardening.yaml`.
- The full corpus with provenance in `MANIFEST.tsv`: `unicode_lipsum`
  samples, Windows-written UTF-16 files, simdutf's own test inputs where
  their licence allows (§10).
- Hostile input: every length 0–200 and around 4096 at each buffer
  boundary, a BOM alone, a NUL in every position, Base64 with every byte
  value in every position (§10).
- libFuzzer targets for `validate`, `convert` and `base64_decode` in
  zucbor's shape, run by `fuzz.yml@v1` from `hardening.yaml`; each target
  trusted once a planted canary has crashed (§10).
- `ZUUTF_SKIP_HEAVY`, `ZUUTF_SLOW_TESTS`, `ZUUTF_TIMING_TESTS` wired as R7
  says; the CRAN suite timed.
- `tools/run-benchmarks` over the §11 table on 256 MB inputs, on every
  kernel the machine supports, with the numbers written into §11 in this
  pull request.

**Exit criteria.**
- `hardening.yaml` is green: the zufast oracle agrees on every corpus file
  and on the random sweep, and every fuzz target runs its canary and its
  clean corpus.
- The CRAN test suite runs in under 15 s on the plain `R CMD check` leg.
- §11 has a measured number in every row, for at least the `fallback`
  kernel and the best kernel of each CI platform, and any missed target is
  recorded rather than lowered.
- `native-checks.yaml`, `kernel-matrix` and `consumer.yaml` stay green.

**Design.** §10, §11.

## Stage 7 — v0.1.0 readiness

**Issue.** [#9](https://github.com/pedrobtz/zuutf/issues/9), sub-issue of
[v0.1.0](https://github.com/pedrobtz/zuutf/issues/1).

**Goal.** Only the submission itself is left. Size: S.

**Work.**
- `Version: 0.1.0` and the matching `NEWS.md` heading listing the §5
  surface and the C table.
- `README.md` with worked examples for validation, UTF-16 decoding and
  Base64; a `vignette("zuutf")` on encodings, error policies and offsets;
  `vignette("linking")` from Stage 5 reviewed.
- `cran-comments.md` listing the r-actions CI legs as test environments
  and the §12.1 outcome.
- The `pkg-cran-review` skill run, every finding resolved;
  `urlchecker::url_check()` and `spelling::spell_check_package()` clean.
- A full-profile r-actions run on the release commit; `pkgdown` site
  rebuilt.

**Exit criteria.**
- `Version: 0.1.0`, `NEWS.md` has a `# zuutf 0.1.0` section, and
  `cran-comments.md` exists.
- `pkg-cran-review` reports no `FAIL` and every `WARN` is resolved or
  explained in `cran-comments.md`.
- `urlchecker::url_check()` and `spelling::spell_check_package()` are clean.
- A full-profile r-actions run is green on the release commit, every
  workflow of §12.2 included.
- Every §14 acceptance criterion holds.

**Design.** §13, §14.

## After 0.1.0

- Streaming conversion over connections and a `readLines()`-style reader
  for UTF-16 files: deferred until a consumer asks (§2, §16 Q3).
- `find` helpers in the C table: deferred until a consumer asks (§2).
- Re-vendoring to the simdutf release that adds UTF-8 to UTF-16 with
  replacement and `validate_utf8_with_counts`, so the §6 loop can use
  them (§8).
- zufast's own header-only SIMD validator: not zuutf's decision (§16 Q2).

## Open questions

- §16 Q1, the `base64_` prefix versus `utf_base64_*`: blocks Stage 4.
- §16 Q4, `url = NA` for either alphabet on decode: blocks Stage 4.
- §12.1, Windows: not a question but a measurement; Stage 1 settles it and
  every later stage depends on its outcome.
- §16 Q2 and Q3 block nothing before 0.1.0.
