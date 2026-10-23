# zuutf — Design

- **Status:** Adopted, 2026-10-13, from
  [RFC 0024](https://github.com/pedrobtz/packages/blob/main/rfcs/not-started/0024-zuutf-unicode-transcoding.md)
  (2026-10-09). This is the package's own specification; the RFC text is
  its starting point, and later changes are made here in the same commit
  as the code they describe. Every statement here is a decision (§15);
  what is not yet decided lives in §16 and nowhere else.
  [roadmap.md](roadmap.md) sequences the work; its section references (§)
  point here. Section 12.1 (Windows) is a go/no-go Stage 1 settles.
- **Package:** `zuutf`, this repository; vendors simdutf (Apache-2.0 or
  MIT at the user's choice; zuutf takes MIT).
- **One line:** every Unicode encoding R meets, validated and converted
  at memory speed, with the exact position of the first error.
- **Source:** the simdutf repository (`simdutf/simdutf`): `README.md`
  (requirements, the single-header amalgamation and its feature switches,
  manual implementation selection, "compiling without the C++ standard
  library", the C API, thread safety, licence); `include/simdutf_c.h`;
  the `v9.2.1` release (2026-09-23) and its `singleheader.zip`;
  `zufast`'s design (`../zufast/.agents/design.md` §2, §14, §17, §19.3),
  which rules out a compiled provider in `zufast`; `zuxml`'s design §15
  (the family's registered-table rules); `zufft`'s design §12 (vendored
  C++ under CRAN's flag checks); the family alignment rules
  ([`zu-family-alignment.md`](https://github.com/pedrobtz/packages/blob/main/zu-family-alignment.md),
  R1–R10).

**What changed between the RFC and this document.** The RFC said nothing
in it had been checked. On 2026-10-13 the `v9.2.1` single-header release
was downloaded, read and compiled on an arm64 Mac with Apple clang 21,
and the places where the RFC's assumptions did not hold are corrected and
marked *verified 2026-10-13*: the C API cannot be amalgamated with fewer
features (§4); the C API has no implementation selection, so one small
C++ shim is needed (§4, D10); `SIMDUTF_NO_LIBCXX` buys nothing under R
and is dropped (§12.2, D9); replacement-character conversion exists in
the C API for one direction only, so zuutf owns a replacement loop (§6,
D8); the kernel matrix in CI uses upstream's `SIMDUTF_FORCE_IMPLEMENTATION`
variable (§10); `iconv()` does read raw vectors, so §1's case against it
was wrong and is restated. The RFC's open question 1 (the name) is closed
by this repository. The RFC itself still sits in `rfcs/not-started/` in
`pedrobtz/packages` and should move to `rfcs/started/`.

---

## 1. What zuutf is

`zuutf` validates and converts text between UTF-8, UTF-16 (LE and BE),
UTF-32 (LE and BE) and Latin-1, counts characters, detects encodings, and
encodes and decodes Base64, through simdutf: the SIMD library in the text
paths of Node.js, Bun, WebKit, Chromium, Cloudflare workerd and
`haskell/text` (*verified 2026-10-13*, upstream README "Real-World
Usage"), which runs at gigabytes per second by choosing a kernel for the
running CPU at first use (x86-64: Westmere SSE4.2, Haswell AVX2, Ice Lake
AVX-512; ARM64 NEON; POWER; RISC-V vectors; LoongArch LSX/LASX; a scalar
fallback everywhere).

R's own tools do the same jobs, slowly and without saying where things
went wrong (*verified 2026-10-13* on R 4.6.1, macOS):

- `validUTF8()` is a scalar loop per element and answers only yes or no.
- `iconv()` accepts a list of raw vectors and returns raw with
  `toRaw = TRUE`, so it does read UTF-16 from bytes; but it is one scalar
  call per element through the platform's converter (glibc, macOS
  libiconv, win_iconv), its treatment of invalid input and byte-order
  marks differs between those converters, and an invalid element becomes
  `NA` with no offset.
- Base64 lives in several packages (`base64enc`, `openssl`, `jsonlite`),
  all scalar, none decoding straight from a raw vector at memory speed.

Users: anyone ingesting large text (log files, CSV exports from Windows
tools in UTF-16, JSON with mixed encodings, payloads with Base64 fields),
and the family's own parsers through the C table (§7).

The one-line statement that governs every decision below:

> **Every Unicode encoding R meets, validated and converted at memory
> speed, with the exact position of the first error.**

Three properties shape the design:

- **The result is the same on every platform and every kernel.** The
  scalar fallback kernel, base R and zufast's DFA agree with every SIMD
  kernel on every input, and CI proves it (§10).
- **Errors carry a position.** Every validation and conversion can report
  the byte offset of the first ill-formed sequence, in the input's units.
- **zuutf owns no text semantics.** Nothing here normalises, folds or
  segments; simdutf's definitions of "valid" are Unicode's, and zuutf
  adds only R's rules (encoding marks, no embedded NUL).

---

## 2. Scope

| | v0.1.0 | Later, when asked | Never |
|---|---|---|---|
| Validation of character, raw and list-of-raw input in UTF-8, UTF-16LE/BE, UTF-32LE/BE and ASCII, as a logical or as the offset of the first error | yes | | |
| Conversion between every pair of UTF-8, UTF-16LE/BE, UTF-32LE/BE and Latin-1, raw to raw, raw to character (marked UTF-8) and character to raw, with three invalid-input policies: error, U+FFFD, `NA` | yes | | |
| Code-point counts and the byte length a conversion will produce | yes | | |
| Base64: standard and URL alphabets, padding on or off, WHATWG forgiving decoding or strict RFC 4648, line wrapping on encode, decoding to raw | yes | | |
| Encoding detection for raw input: byte-order mark first, simdutf's detector second | yes | | |
| A registered C table (§7) for packages that want SIMD validation and transcoding in their own C | yes | | |
| Streaming conversion over connections (a code point split across chunks carried between calls) | | §16 Q3 | |
| A `readLines()`-style reader for UTF-16 files on top of the streaming converter | | §16 Q3 | |
| `find` helpers (simdutf's SIMD byte search) in the C table | | when a consumer asks | |
| Unicode normalisation, case folding, collation, grapheme and word segmentation | | | `stringi` (ICU) |
| Encodings beyond Latin-1 and the UTFs (Windows-1252, Shift-JIS, GB18030, …) | | | `iconv()`, `stringi` |
| A header-only mode | | | zufast's §19.3 is that route (§3) |

---

## 3. Position in the `zu*` family

These are zuutf's rows for the family table that alignment rule R1 places
in `pedrobtz/packages` as `zu-family.md`; until that file exists they
live here.

| | zuutf |
|---|---|
| Role | provider (registered table); R API |
| R prefix | `utf_`, `base64_` |
| Info function | `zuutf_info()` (the package name, as R1 recommends) |
| Root condition class | `zuutf_error` |
| Public C prefix | `zuutf_` / `ZUUTF_` in the installed header; internal `zut_` / `ZUT_` |
| From C | `Imports` + `LinkingTo`; `R_GetCCallable("zuutf", "zuutf_api_v1")` through `ZUUTF_DEFINE_API_GET` (§7) |
| Hides symbols (`$(C_VISIBILITY)`, `$(CXX_VISIBILITY)`) | yes, from Stage 0 (R3) |
| Vendored code | simdutf `v9.2.1` single-header release, all features (§8) |
| `SystemRequirements` | `C++17` |
| `LinkingTo`, `Imports` | none |
| `Suggests` | `testthat`, `withr`, `knitr`, `rmarkdown`, `base64enc` (benchmarks only) |
| `Depends: R` | 4.1 (R2) |
| Language | en-GB (R2) |
| Test switches | `ZUUTF_SKIP_HEAVY`, `ZUUTF_SLOW_TESTS`, `ZUUTF_TIMING_TESTS` (R7) |

`zut_` is free: no sibling's `src/` or `inst/include/` uses it
(*verified 2026-10-13*, a search of every `zu*` checkout).

### 3.1 Relationships, as decided rather than as hoped

- **`zufast`** keeps its scalar UTF-8 DFA (`zuf_utf8_valid()`,
  `zuf_utf8_count()`) and its strict scalar Base64 (*verified
  2026-10-13*, zufast design §14 and §17). Its design forbids a compiled
  provider, C++, intrinsics and a function table, so simdutf cannot live
  there. A family parser that needs SIMD speed for UTF-8 validation alone
  and cannot take a run-time dependency has zufast's §19.3 path (target
  attributes inside the header); zuutf is the route for everything else.
- **zufast is an oracle, not a dependency.** zuutf has no run-time use for
  zufast and declares no `LinkingTo` on it (R10.2 would otherwise tie
  zuutf's submission to zufast's). The DFA and the strict Base64 decoder
  are compiled into a CI-only fixture under `tools/` that runs the
  corpus through both libraries (§10, D12).
- **`zucsv`, `zujson`, `zucbor`, `zuxml`** are candidate consumers of the
  C table for their validation passes, at their maintainers' choice and
  under R10.1 (adopt only when it removes code the consumer tests
  itself); none is required to adopt it.
- **`zubin`** is unaffected: it reads binary layouts, not text.

### 3.2 What exists elsewhere

- Base R: `validUTF8()`, `iconv()`, `enc2utf8()`, `utf8ToInt()`,
  `intToUtf8()`.
- `stringi` (ICU): complete Unicode; `stri_enc_isutf8()`,
  `stri_encode()`; scalar per element and not built for raw-vector
  transcoding.
- `base64enc`, `openssl`, `jsonlite`: scalar Base64; `b64` (Rust)
  carries its own SIMD codec for Base64 only.
- `utf8` (CRAN): validation and display utilities, scalar.
- No R binding of simdutf was found on CRAN or GitHub (2026-10-09).

---

## 4. Architecture

```text
R vector (character / raw / list of raw)
   |
   v
R layer (R/): argument checks, encoding names, the invalid= policy,
              list-of-raw dispatch
   |
   v
C glue (src/zut_*.c)        <--- the replacement loop (§6), BOM handling,
   |                             UTF-32 byte swaps, NUL checks, R allocation
   v
simdutf C API (src/vendor/simdutf/simdutf_c.h, implemented inside
simdutf.cpp)                <--- validation, conversion, lengths, Base64,
   |                             detection; runtime CPU dispatch on first call
   v
one C++ shim (src/zut_impl.cpp, extern "C"): lists kernels, reports the
active one, forces one for tests
   |
   v
R result: logical / integer offsets / raw / character (marked UTF-8)
```

- zuutf's own code is C99, plus one C++17 file of about forty lines. The
  C API has no implementation selection (*verified 2026-10-13*: nothing
  in `simdutf_c.h` names an implementation), and `zuutf_info()` must
  report the active kernel and §12.1 must disable kernels per platform,
  so the shim wraps `simdutf::get_active_implementation()` and
  `get_available_implementations()`. No C++ type crosses into the glue;
  the shim returns `const char *` and `int`.
- The amalgamation is generated with every feature. The C API "is
  currently not aware of amalgamation with limited features. It expects
  the full simdutf library" (*verified 2026-10-13*, upstream README), so
  the feature switches the RFC planned to use are not available while
  zuutf goes through `simdutf_c.h`. The cost is known (§12.2): 4 s of
  compile time and a 340 KB object.
- Per element for character vectors and lists of raw; one call for a raw
  vector. Output buffers are sized by simdutf's length functions and
  allocated once as the R result; a `_safe` variant with an explicit
  capacity is used wherever the C API offers one, so a wrong length
  estimate is an error, never an overrun. That is Latin-1 to UTF-8, and
  UTF-16 to UTF-8 with replacement in native byte order; the other calls,
  the opposite-order replacement among them, have no `_safe` form and rely
  on the length pass. Every element's written length is compared with its
  measured length, and a difference is a `zuutf_internal_error`. simdutf
  documents `convert_latin1_to_utf8_safe` as up to four times slower on
  short inputs; the bound is kept anyway (review #27).
- No R API call happens between a simdutf call and the use of its result;
  `R_CheckUserInterrupt()` runs between elements, never inside a call.
  simdutf calls are `noexcept` and never `longjmp`, so no R error passes
  through a C++ frame.

---

## 5. Public R API (complete v0.1.0 surface)

```r
# validation
utf_valid(x, encoding = "UTF-8")      # logical, one per element
utf_error_at(x, encoding = "UTF-8")   # integer byte offset of the first error, NA if valid
utf_is_ascii(x)

# conversion
utf_convert(x, from, to, invalid = c("error", "replace", "na"))
                                      # raw (or list of raw) -> raw (or list of raw)
utf_decode(x, from = "auto", invalid = c("error", "replace", "na"))
                                      # raw (or list of raw) -> character, marked UTF-8
utf_encode(x, to = "UTF-16LE", invalid = c("error", "replace", "na"))
                                      # character -> raw (or list of raw)
utf_detect(x)                         # character vector of candidate encodings, best first

# lengths
utf_count(x, encoding = "UTF-8")      # code points per element; NA where invalid
utf_length_as(x, from = "UTF-8", to)  # bytes a conversion will produce, per element

# Base64
base64_encode(x, url = FALSE, pad = TRUE, line_length = NULL)   # -> one string
base64_decode(x, url = FALSE, forgiving = TRUE)                 # -> raw; url = NA: either alphabet

zuutf_info()                          # simdutf version, kernels available, kernel in use, build facts
```

**Input shapes.** `x` is a character vector, a raw vector (one element)
or a list of raw vectors (one element each); `NULL` elements of a list
and `NA` strings give `NA` results. Functions that return one value per
element return a vector of that length; `utf_convert()` and
`utf_encode()` return a raw vector for one-element input and a list of
raw otherwise, like `iconv(toRaw = TRUE)`: one-element input is a raw
vector, or a single string for `utf_encode()`, and a list stays a list
whatever its length (Stage 3, 2026-10-13). A single string's name is
dropped with the list, and an `NA` single string, or one invalid under
`"na"`, gives `NULL`, the missing element unwrapped (review #48).

**Encoding names.** `"UTF-8"`, `"UTF-16LE"`, `"UTF-16BE"`, `"UTF-32LE"`,
`"UTF-32BE"`, `"Latin-1"`, `"ASCII"` (validation only), matched without
regard to case or hyphens (`"utf8"` is `"UTF-8"`). `"UTF-16"` and
`"UTF-32"` are accepted as `from` only: a byte-order mark decides, and
without one the input is big-endian, as RFC 2781 and `iconv()` read it
(*verified 2026-10-13*: `iconv(x, "UTF-16", "UTF-8")` on bytes without a
BOM decodes them big-endian). `from = "auto"` (the default of
`utf_decode()`, and accepted by `utf_convert()`) applies `utf_detect()`
and takes its first candidate, or UTF-8 when there is none, so that the
`invalid` policy decides (Stage 3, 2026-10-13).

**Character input** is taken as its marked encoding: UTF-8 strings as
they are, Latin-1-marked strings converted from Latin-1, native strings
through `enc2utf8()` first, and `"bytes"`-marked strings refused with
`zuutf_invalid_argument`; `useBytes = TRUE` on `utf_valid()`,
`utf_error_at()` and `utf_count()` reads the bytes of any string as they
are, which is how a caller checks a string R believes is UTF-8. Without
`useBytes` a string's bytes are its UTF-8 form, so `encoding` must then
be `"UTF-8"` or `"ASCII"`, and `from` of `utf_length_as()` `"UTF-8"`; any
other name is `zuutf_invalid_argument` (Stage 2, 2026-10-13). `utf_is_ascii()` reads
the bytes of every string as they are, since ASCII is the same in UTF-8
and every native encoding R supports.

**Base64** takes one string or one raw vector and returns one string
(encode) or one raw vector (decode); a vector of strings is a job for
`lapply()`. A string given to `base64_encode()` is encoded as its UTF-8
bytes. `line_length` inserts `"\n"` after that many characters, as
simdutf's `binary_to_base64_with_lines` writes it; MIME's CRLF is the
caller's `gsub()`.

---

## 6. Semantics

- **Errors.** `invalid = "error"` raises `zuutf_encoding_error` with the
  element `index`, the byte `offset` in the input's units and the
  `encoding`; `"replace"` substitutes U+FFFD, one per maximal invalid
  subpart as the WHATWG decoder does (one per unpaired surrogate in
  UTF-16, one per out-of-range unit in UTF-32); `"na"` returns `NA` for
  that element. With a Latin-1 target, code points above U+00FF are
  "invalid" for these policies and `"replace"` writes `?` (0x3F), as
  `iconv(sub = "?")` would, because Latin-1 has no U+FFFD.
- **How replacement is done (D8).** The C API offers replacement for
  UTF-16 to UTF-8 only in `v9.2.1` (`convert_utf16*_to_utf8_with_replacement`;
  UTF-8 to UTF-16 is on upstream `master` and unreleased; *verified 2026-10-13*).
  zuutf therefore owns one loop that works for every pair: validate with
  the `_with_errors` function to the first error, convert the valid
  prefix with the `convert_valid_*` function, write U+FFFD, skip the
  maximal subpart (a twenty-line scalar rule for UTF-8; one unit for
  UTF-16 and UTF-32), repeat. The bulk work stays in simdutf; the scalar
  code runs only at errors. Where simdutf has a `_with_replacement`
  function it is used, and a test shows the two agree on the corpus.
- **NUL.** R strings cannot hold U+0000. Decoding a sequence that
  contains it to `character` raises `zuutf_nul_error` with the index and
  offset, under every `invalid` policy, because the input is valid
  Unicode and only R refuses it; `utf_convert()` to raw keeps it. Under
  `"error"` the earlier of the NUL and an ill-formed sequence decides the
  condition; under `"na"` an ill-formed element is `NA` whatever else it
  holds (Stage 3, 2026-10-13).
- **BOM.** `utf_decode()` and `utf_convert()` strip a leading byte-order
  mark that matches `from`; with `"UTF-16"`, `"UTF-32"` or `"auto"` they
  use it to choose. Output never carries a BOM; a caller who wants one
  prepends it. Validation, `utf_count()` and `utf_length_as()` skip a
  matching BOM the same way, so §9's offsets and the counts never include
  it.
- **UTF-32 byte order (D13).** simdutf's UTF-32 functions take native
  `char32_t`, and the C API has no UTF-32BE entry points (*verified
  2026-10-13*). The non-native order is byte-swapped in the glue into a
  scratch buffer before and after the simdutf call; the swap is
  memory-bound and cheap next to the conversion, and the fixture tests
  (§10) run the swap path on both byte orders.
- **Surrogates.** Unpaired surrogates in UTF-16 are invalid; UTF-8
  encodings of surrogates, overlong forms, code points above U+10FFFF and
  truncated sequences are invalid, as Unicode requires and as
  `validUTF8()` agrees (*verified 2026-10-13* on all four cases).
- **Base64.** `forgiving = TRUE` is the WHATWG forgiving-base64
  algorithm: ASCII whitespace ignored, padding optional, a final quantum
  of one character an error; it maps to simdutf's default options with
  `SIMDUTF_LAST_CHUNK_LOOSE`. `forgiving = FALSE` is RFC 4648 §3.3 read
  strictly: padding required, non-zero unused trailing bits an error
  (`SIMDUTF_LAST_CHUNK_STRICT`), and whitespace an error too, which
  simdutf never enforces by itself and zuutf checks with one scan of the
  input before decoding. The strict mode accepts exactly what zufast's
  decoder accepts, so zufast is its oracle; the forgiving mode is checked
  against the WHATWG test vectors. Decoding errors raise
  `zuutf_base64_error` with the `offset` of the offending character.
  `pad = FALSE` on encode omits `=`; `url = TRUE` selects the `-_`
  alphabet on both sides, and `url = NA` on decode accepts either
  (`SIMDUTF_BASE64_DEFAULT_OR_URL`, D18). For an input with too much
  padding the offset is simdutf's: the first `=` of the run.
- **Detection.** `utf_detect()` returns the BOM's encoding alone when
  there is one; otherwise every encoding the bytes are valid in, UTF-8
  first, then UTF-16LE, UTF-16BE, UTF-32LE, UTF-32BE; and `character(0)`
  when none fits. simdutf's `detect_encodings` tries UTF-8, UTF-16LE and
  UTF-32LE only and never reports a big-endian candidate (*verified
  2026-10-13*, `simdutf.cpp`, every kernel), so zuutf runs simdutf's five
  validators itself (Stage 3). It never guesses Latin-1,
  which every byte string satisfies.

---

## 7. The C table

```c
/* inst/include/zuutf.h; registered with R_RegisterCCallable("zuutf", "zuutf_api_v1") */
typedef struct {
  int    error;   /* 0 on success; otherwise a ZUUTF_ERR_* code mirroring simdutf's */
  size_t count;   /* units written, or the offset of the error in input units */
} zuutf_result;

typedef struct {
  uint32_t struct_size;                 /* the only version discriminator */
  zuutf_result (*validate_utf8)(const char *s, size_t n);
  zuutf_result (*validate_utf16le)(const uint16_t *s, size_t n);
  zuutf_result (*validate_utf32)(const uint32_t *s, size_t n);
  int    (*validate_ascii)(const char *s, size_t n);
  size_t (*count_utf8)(const char *s, size_t n);
  size_t (*utf8_length_from_utf16le)(const uint16_t *s, size_t n);
  size_t (*utf16_length_from_utf8)(const char *s, size_t n);
  zuutf_result (*utf16le_to_utf8)(const uint16_t *s, size_t n, char *out, size_t cap);
  zuutf_result (*utf8_to_utf16le)(const char *s, size_t n, uint16_t *out, size_t cap);
  zuutf_result (*latin1_to_utf8)(const char *s, size_t n, char *out, size_t cap);
  size_t (*base64_encoded_length)(size_t n, unsigned flags);
  size_t (*base64_encode)(const unsigned char *s, size_t n, char *out, unsigned flags);
  zuutf_result (*base64_decode)(const char *s, size_t n, unsigned char *out,
                                size_t cap, unsigned flags);
  const char *(*kernel)(void);          /* the active simdutf implementation's name */
  int (*kernel_ok)(void);               /* 1 when that kernel runs here (review #36) */
  /* appended over time, never reordered or removed */
} zuutf_api;
```

The member list is a sketch; the member order that is ABI is the one in
`inst/include/zuutf.h`. As shipped in Stage 5 (2026-10-13) it differs from
the sketch in three places: `base64_encode` takes an output capacity and
returns a `zuutf_result`, like every member that writes;
`base64_decoded_max_length` is added so a consumer can size the decode
buffer; and the Base64 `flags` are `ZUUTF_BASE64_URL`, `_NO_PAD`, `_STRICT`
and `_EITHER`. On `ZUUTF_ERR_OUTPUT_BUFFER_TOO_SMALL`, `count` is the
capacity that would have been enough. The table is reached through a
getter registered as `zuutf_api_v1`, as zuxml's is. Rules, all `zuxml`'s
(its design §15):

- `struct_size` is the sole version discriminator for the table. A
  consumer compares it against the offset of the member it wants
  (`ZUUTF_API_HAS(api, member)`) and degrades gracefully. Members are
  appended, never reordered or removed. The registered **name** is bumped
  (`zuutf_api_v2`) only for a layout change in another public type, such
  as `zuutf_result`.
- The header includes `<stddef.h>` and `<stdint.h>` only: no simdutf
  type, no `<uchar.h>` (UTF-16 and UTF-32 are `uint16_t` and `uint32_t`),
  no R header. The `utf16le` members read and write little-endian bytes
  whatever the host's order, as simdutf's `*le` functions do; UTF-32 is
  in native order (review #37). `ZUUTF_DEFINE_API_GET`, defined in exactly one of the
  consumer's translation units after `<R_ext/Rdynload.h>`, emits a
  `zuutf_api_get()` that reads `R_GetCCallable()`'s `DL_FUNC` through a
  union, as zuxml's does, so clang's `-Wcast-function-type` stays quiet.
- Every conversion member takes an explicit output capacity and reports
  `SIMDUTF_ERROR_OUTPUT_BUFFER_TOO_SMALL` under its `ZUUTF_ERR_` name
  rather than writing past `cap`; the length members say how much to
  allocate.
- A consumer declares `Imports: zuutf` **and** `LinkingTo: zuutf`, and
  carries `importFrom(zuutf, zuutf_info)` in its `NAMESPACE`, because
  `R_GetCCallable()` resolves nothing until zuutf's namespace is loaded.
- `kernel_ok()` is the table's `check_kernel()` (§10): a consumer checks
  it once before any other member, since a forced kernel the processor
  lacks dies of SIGILL inside the first member called.
- All members are pure functions of their arguments. The first call from
  any thread runs CPU detection, which simdutf makes thread-safe; none
  calls into R, so a consumer may call them off the main thread.
- `tools/zuutftest` is the consumer fixture (R10.4): it calls every
  member through `zuutf_api_get()`, carries a frozen copy of the 0.1.0
  table whose member offsets must match the current header, and is
  installed by `consumer.yaml` with zuutf's `main` removed from the
  library path, so a missing export fails there and not in a consumer.

---

## 8. The vendored library, as zuutf uses it

- **Files.** `src/vendor/simdutf/simdutf.h`, `simdutf.cpp` (which
  contains the C API's implementation; *verified 2026-10-13*) and
  `simdutf_c.h`, taken from the release artefact `singleheader.zip` of
  `v9.2.1`, not regenerated with `amalgamate.py`: the artefact is what
  upstream publishes and tests, it needs no Python in the vendoring
  pipeline, and it has one checksum to record. Sizes (*verified
  2026-10-13*): `simdutf.cpp` 69,515 lines, 2.88 MB, 389 KB gzipped;
  `simdutf.h` 14,536 lines, 573 KB, 62 KB gzipped; `simdutf_c.h` 382
  lines, 114 functions. The source tarball stays well under CRAN's 5 MB.
- **Manifest.** `tools/vendor/manifest.tsv` with zucrypt's columns
  (`source repo tag commit version_string archive archive_sha256 license
  defines patches`), `tools/vendor/checksums.sha256`, and the scripts
  `fetch`, `apply` and `verify` (offline; run by `vendor.yaml`, R5/R6).
  The first row: tag `v9.2.1`, archive `singleheader.zip`, SHA-256
  `a1b1fc3a3a8358820438f663237e9f252ce5ad356ae283ac066dcc9212eaa4dc`
  (*verified 2026-10-13*). The licence (MIT option) goes to
  `inst/COPYRIGHTS` and `LICENSE.note`; Daniel Lemire and the simdutf
  contributors get `cph` in `Authors@R`.
- **Patches: none** (*verified 2026-10-13*). The amalgamation's `printf`
  calls are debug `dump()` helpers that the compiled object does not
  reference; it has no `abort()`, `exit()` or `stderr` use (upstream
  forbids them, with a comment saying so); its only libc references are
  `getenv`, `memcpy`, `memmove`, `memcmp` and `strlen`. `getenv` reads
  `SIMDUTF_FORCE_IMPLEMENTATION` once, on first use (§10). The
  `native-checks` job greps the installed object for `printf`, `abort`,
  `exit` and `stderr` so a future release cannot bring them in silently.
  On Windows the check allows `abort`, `exit`, `_exit` and
  `__acrt_iob_func` (UCRT's access to `stderr`): Rtools links the C++
  runtime into every C++ DLL statically, and its `std::terminate` path
  imports them whatever the package does; the Linux and macOS objects,
  linked to a shared C++ runtime, reference none of the four, which is what
  shows the vendored code does not (*verified 2026-10-13*, CI).
- **Standard library.** The amalgamation includes `<limits>`,
  `<type_traits>`, `<cstdint>`, `<array>`, `<tuple>`, `<utility>`,
  `<initializer_list>` and `<climits>` only; it needs the C++ runtime for
  `__cxa_begin_catch`, `__cxa_guard_acquire` and `_release` (the
  function-local statics), `__cxa_pure_virtual`, `__gxx_personality_v0`,
  `std::terminate` and two `type_info` vtables (*verified 2026-10-13*). R links the C++ runtime
  into any package with a `.cpp` source, so this costs nothing (§12.2).
- **Re-vendoring.** Upstream releases often. zuutf re-vendors on releases
  with fixes in validation, conversion or Base64 (the `v9.2.1` notes list
  two buffer-overrun fixes, which is the kind that matters), after the
  full test suite and the kernel matrix; upstream `master` (2026-10-13) already adds
  UTF-8 to UTF-16 with replacement and `validate_utf8_with_counts`, which
  §6's loop can use once released.

---

## 9. Errors

Every condition inherits `zuutf_error`:

| Class | Fields | Raised when |
|---|---|---|
| `zuutf_invalid_argument` | | wrong type, unknown encoding name, a `"bytes"` string without `useBytes` |
| `zuutf_encoding_error` | `index`, `offset`, `encoding` | `invalid = "error"` and the input is ill-formed, or unrepresentable in a Latin-1 target |
| `zuutf_nul_error` | `index`, `offset` | decoding to `character` meets U+0000 |
| `zuutf_base64_error` | `offset` | a Base64 input the chosen mode rejects |
| `zuutf_size_error` | | an output longer than a `CHARSXP` (2^31 − 1 bytes) or a raw vector can hold |
| `zuutf_internal_error` | | a simdutf result the glue did not expect, or the forced kernel is `unsupported` (§10) |

Offsets are 1-based in R, in the input's units (bytes for UTF-8, Latin-1
and Base64; code units for UTF-16 and UTF-32), and always refer to the
input after any BOM was stripped. Tests assert on the class, never the
message.

---

## 10. Testing

- **Oracles.** R's `validUTF8()`, `iconv()` and `utf8ToInt()` in the
  CRAN suite: validation results must agree, and conversions must be
  byte-identical where `iconv()` succeeds. On a list of raw vectors with
  `toRaw = TRUE`, `iconv()` returns a failed element unchanged rather
  than `NULL` (*verified 2026-10-13*, R 4.6.1, macOS libiconv: `"cœ"` to
  `"latin1"`), so the tests decide where it can succeed from the input,
  not from its result. zufast's `zuf_utf8_valid()`,
  `zuf_utf8_count()` and strict Base64 decoder in a CI-only fixture
  (`tools/zuutforacle`, `LinkingTo: zufast`, built by `hardening.yaml`;
  D12): validation results, counts and error offsets must agree on every
  corpus file and on a million random byte strings. zufast reports
  validity and the code points before the first error, not an offset;
  since the bytes before the error are valid, the fixture walks that many
  code points to find where the bad sequence starts, which is what zuutf
  reports (Stage 6, 2026-10-13). simdutf's own
  `fallback` kernel is the oracle for its SIMD kernels, run through the
  kernel matrix below.
- **Corpus** (`tests/testthat/fixtures/`, each file with provenance in a
  `MANIFEST.tsv`): Markus Kuhn's UTF-8 stress test and its WHATWG
  replacement, a multi-script sample in UTF-8, UTF-16 and UTF-32 in both
  byte orders with and without BOM, and the WHATWG and RFC 4648 Base64
  vectors. Beside it, in `hardening.yaml` only: the `unicode_lipsum`
  samples, fetched at a pinned commit because that repository carries no
  licence of its own (the samples come from simdutf8, MIT or Apache-2.0),
  and UTF-16 and UTF-8 files that Windows PowerShell 5.1 writes on the
  Windows runner. simdutf's own tests generate their inputs in code, so
  there is no data of theirs to take (Stage 6, 2026-10-13).
- **Kernel matrix.** simdutf reads `SIMDUTF_FORCE_IMPLEMENTATION` from
  the environment on first use and makes that kernel active; an unknown
  name selects its `unsupported` stub, but a kernel that is compiled in
  and that the processor cannot run is made active anyway, and its first
  call dies of an illegal instruction (*corrected 2026-10-13*, Stage 2: a
  forced `icelake` on a runner without AVX-512 exited with SIGILL; `set_best()`
  does not call `supported_by_runtime_system()`). Every R function
  therefore checks, before any simdutf call, that the active kernel is a
  real one the processor supports, and raises `zuutf_internal_error`
  otherwise. The
  `kernel-matrix` job therefore runs the suite once per kernel the
  runner supports (`fallback` and `westmere` on every x86-64 leg;
  `haswell` on the GitHub runners; `icelake` where the runner has
  AVX-512 VBMI2; `arm64` on macOS), sets the variable before R starts,
  and asserts `zuutf_info()$kernel` equals it, so a run on the stub
  fails rather than passes vacuously. For tests inside one process, the
  shim's `zut_force_kernel()` (unexported) switches the active
  implementation after start-up.
- **Hostile input.** Truncated sequences at every buffer boundary (the
  SIMD kernels process 64-byte blocks, so inputs of every length from 0
  to 200 bytes and around 4096), overlong encodings, surrogates, values
  above U+10FFFF, a BOM alone, a NUL in every position, Base64 with
  every byte value in every position and every length modulo 4.
- **Hardening** (`hardening.yaml`): UBSan, ASan, valgrind, gctorture,
  rchk and LTO from `native-checks.yaml`; libFuzzer targets for
  `validate`, `convert` and `base64_decode` in the family's fuzz shape
  (`zufuzz` is a skeleton as of 2026-10-13, so the targets are built
  the way zubin's are until it ships). The targets embed R and drive
  zuutf's own `.Call` entry points, so what is fuzzed is the glue R calls,
  simdutf included; each checks invariants (a replaced result is valid in
  its target, a conversion under `"error"` round-trips, what decodes
  re-encodes canonically) and has a canary build that must crash on its
  canary input before the target is trusted (`tools/run-fuzz`).
- **Branches no R test reaches.** Each is listed with why, so that
  coverage gaps are decisions and not oversights (review #35):
  - `ZUT_TOO_LONG` in `zut_convert.c` and `ZUT_B64_TOO_LONG` in
    `zut_base64.c`, and the double branch of `as_count()`: they need an
    output or input past 2^31 - 1 bytes, too large for any test suite.
  - `ZUT_INTERNAL` (written length other than measured) in
    `zut_convert.c`, `ZUT_B64_INTERNAL` (`wrote != len`, and simdutf
    error codes zuutf does not expect) in `zut_base64.c`: they need
    simdutf to disagree with itself.
  - Big-endian hosts: the `zut_little_endian()` false branches in
    `zut_view.c` and `zut_input.c`; no CI leg is big-endian.
  - An actual user interrupt: `R_CheckUserInterrupt()` is reached by
    inputs of 1024 elements or more, and every allocation is R's and
    protected, so a longjmp there leaks nothing, but no test sends one.

  The R side of each status is tested directly, through `raise_status()`
  and `run_base64()` (`test-conditions.R`).
- **Symbols.** `test-abi.R` greps the installed shared object for
  exports: `R_init_zuutf` and, on Linux with GCC, libstdc++ template
  instantiations only, as zufft accepts them (R3, §12.2).
- CRAN suite under 15 s; everything above the corpus and the oracle check
  is behind `ZUUTF_SLOW_TESTS` (R7). In the CRAN suite the hostile sweeps
  run on the kernel in use, since the kernel-matrix job runs the whole
  suite once per kernel; `ZUUTF_SLOW_TESTS` runs them on every kernel in
  process too. `ZUUTF_SKIP_HEAVY` shrinks the random sweeps for gctorture,
  and `ZUUTF_TIMING_TESTS` turns on an elapsed-time check, meaningful only
  against an installed package, since `devtools::load_all()` compiles
  with `-O0`.

---

## 11. Performance targets

Measured by `tools/run-benchmarks` in Stage 6 and recorded here, on a
256 MB input (large enough to defeat caches, small enough for CI):

| Operation | Baseline | Target |
|---|---|---|
| `utf_valid()` on raw UTF-8 | `validUTF8()` on the same bytes as one string | ≥ 10× |
| `utf_decode(from = "UTF-16LE")` | `iconv(list(raw), "UTF-16LE", "UTF-8")` | ≥ 10× |
| `utf_convert("UTF-8", "UTF-16LE")` | `iconv(..., toRaw = TRUE)` | ≥ 10× |
| `base64_decode()` | `base64enc::base64decode()` | ≥ 5× |
| `base64_encode()` | `base64enc::base64encode()` | ≥ 5× |

A target that is missed on a kernel is recorded with the number, not
quietly lowered; the `fallback` kernel is reported too, since it is what
§12.1's worst case ships on Windows.

**Measured** (Stage 6, 2026-10-13; `benchmarks.yaml`, 256 MB inputs, best
of three, R 4.6.1;
[run 38445924915](https://github.com/pedrobtz/zuutf/actions/runs/38445924915)).
Speed-up over the baseline, for the best kernel and for `fallback`; a
target missed is in bold:

| Operation | Target | Linux, AMD EPYC (icelake / fallback) | Windows, AMD EPYC 9V74 (icelake / fallback) | macOS, Apple M1 (arm64 / fallback) |
|---|---|---|---|---|
| `utf_valid()` | ≥ 10× | 11.3 / **6.3** | 22.0 / 23.0 | **5.4** / **4.0** |
| `utf_decode(from = "UTF-16LE")` | ≥ 10× | **1.9** / **1.2** | 13.1 / **7.1** | **3.4** / **2.7** |
| `utf_convert("UTF-8", "UTF-16LE")` | ≥ 10× | **7.1** / **2.3** | 67.6 / 14.5 | 24.7 / **8.3** |
| `base64_decode()` | ≥ 5× | 28.5 / 17.4 | 28.9 / 13.7 | 51.8 / 12.7 |
| `base64_encode()` | ≥ 5× | **1.2** / **1.0** | **1.4** / **1.1** | **1.2** / **1.4** |

In seconds, zuutf against baseline on the best kernel: `utf_valid()`
0.024 / 0.272 (Linux), 0.01 / 0.22 (Windows), 0.033 / 0.178 (macOS);
`utf_decode()` 0.86 / 1.65, 0.63 / 8.27, 1.33 / 4.57; `utf_convert()`
0.16 / 1.11, 0.12 / 8.11, 0.11 / 2.74; `base64_decode()` 0.12 / 3.48,
0.09 / 2.60, 0.04 / 2.23; `base64_encode()` 0.65 / 0.81, 0.45 / 0.61,
0.55 / 0.68.

What the misses are. `base64_encode()` and `utf_decode()` end by making
one R string of 340 MB and 256 MB; R checks and hashes every CHARSXP it
makes, and that, not simdutf, is most of their time, which is also what
the baselines pay. `validUTF8()` is a fast C loop with an ASCII fast path
(0.14 to 0.27 s for 256 MB), and glibc's and macOS's `iconv()` are much
faster than Windows', so the ratios against them are smaller there. None
of these targets is lowered (§11); a string-free decoding path is the
lever if one is wanted after 0.1.0.

---

## 12. Build, portability and CRAN

### 12.1 Windows: the go/no-go

simdutf's README says "GCC under Windows is buggy and thus unsupported"
(*verified 2026-10-13*), and CRAN builds Windows binaries with Rtools'
GCC (MinGW-w64; GCC 14 in Rtools 4.5). Stage 1 must show, before
any R function is written:

1. the amalgamation compiles under Rtools with CRAN's flags, with every
   x86-64 kernel;
2. zuutf's corpus and oracle tests pass on the Windows CI leg with each
   kernel the runner supports forced in turn (§10), and the AVX-512
   kernel on a runner that has it.

If one kernel misbehaves under MinGW GCC (AVX-512 is the usual suspect),
it is disabled on Windows only: the amalgamation honours
`SIMDUTF_IMPLEMENTATION_ICELAKE=0`, `_HASWELL=0`, `_WESTMERE=0` as
`-D` flags in `PKG_CPPFLAGS` of `Makevars.win` (*verified 2026-10-13*:
each is `#ifndef`-guarded in `simdutf.cpp`), and `zuutf_info()` reports
the kernels compiled in. If the library as a whole cannot be made
correct under Rtools, zuutf ships the scalar `fallback` kernel alone on
Windows, which is still correct and still faster than `iconv()`, and
the outcome is recorded here with the numbers.

**Outcome (2026-10-13, Stage 1): go, with every kernel.** The
amalgamation compiles under Rtools 4.5's GCC 14.3.0 with CRAN's flags and
no `-D` switch. On `windows-latest` the kernel-matrix job forced
`icelake`, `haswell`, `westmere` and `fallback` in turn, confirmed each
with `zuutf_info()$kernel`, and passed the whole suite on each, including
the probe against `validUTF8()` at every length from 1 to 130 and 4090 to
4100 bytes ([run 38387588919](https://github.com/pedrobtz/zuutf/actions/runs/38387588919),
attempt 2, on an AMD EPYC 9V45). Runner hardware varies: an AMD EPYC 7763
has no AVX-512, and the job then runs the other three, which is why it
asks the processor rather than listing kernels per runner. `Makevars.win`
therefore carries no `SIMDUTF_IMPLEMENTATION_<KERNEL>=0`. The corpus and
oracle tests of Stages 2–6 run on the same matrix, so a MinGW-only
miscompilation the probe misses would still surface there.

### 12.2 Everywhere

- `src/Makevars`: `CXX_STD = CXX17`, `PKG_CXXFLAGS = $(CXX_VISIBILITY)`,
  `PKG_CFLAGS = $(C_VISIBILITY)`,
  `PKG_CPPFLAGS = -Ivendor/simdutf -DSIMDUTF_IMPLEMENTATION_FALLBACK=1`
  (the compiler runs in `src/`, so the path is relative to it), and an
  explicit `OBJECTS` list, because R compiles no subdirectory of `src/` by
  itself; `Makevars.win` the same plus any §12.1 `-D` switches, and
  `src/zuutf-win.def` exporting `R_init_zuutf` alone, since a PE DLL has no
  visibility attributes. No `configure`, no GNU make, no system library.
  `SystemRequirements: C++17`.
- **The `fallback` kernel is compiled everywhere (D16).** simdutf leaves it
  out when some SIMD kernel can always run, which on arm64 is always:
  without the switch an arm64 build has the `arm64` kernel alone
  (*verified 2026-10-13*, `simdutf.cpp`, `SIMDUTF_IMPLEMENTATION_FALLBACK`).
  `-DSIMDUTF_IMPLEMENTATION_FALLBACK=1` keeps the scalar kernel in every
  build, so §1's "a scalar fallback everywhere" holds and §10's oracle runs
  on the arm64 legs too.
- `-pedantic` reports two `-Wextra-semi` warnings per kernel (a stray `;`
  after two declarations in each kernel's class; *verified 2026-10-13*,
  Apple clang 21). R CMD check does not count `-Wextra-semi` among its
  significant warnings, so no patch is needed (D11 stands).
- No compiler flags beyond CRAN's: simdutf compiles every x86-64 kernel
  with function-level target attributes
  (`SIMDUTF_TARGET_REGION("avx2,bmi,lzcnt,popcnt")` and the like;
  *verified 2026-10-13*) and picks one at run time, so no `-mavx2`-style
  flag is needed, and none may be written: R's `Makevars` check rejects
  every `-m*`, `-f*`, `-O*` and `-std*` token in `PKG_*FLAGS` as a
  WARNING (zufft design §12.3). `$(CXX_VISIBILITY)` passes because it is
  a `Makeconf` macro the check does not expand.
- **`SIMDUTF_NO_LIBCXX` is not used (D9).** It is experimental, GCC and
  clang only, forces translation-unit-scope static initialisation, and
  still leaves `__cxa_begin_catch`, `__gxx_personality_v0` and
  `std::terminate` unresolved unless `-fno-exceptions -fno-rtti` are
  passed, which the `Makevars` check forbids (*verified 2026-10-13*). R
  links the C++ runtime into a package with any `.cpp` source anyway, so
  the saving would be 76 KB of object and one second of compile time.
- **Measured** (*2026-10-13*, Apple clang 21, arm64,
  `-std=gnu++17 -O2 -fPIC -fvisibility=hidden`, R 4.6.1's flags): the
  amalgamation compiles in 4.2 s to a 340 KB object; linked as a shared
  library it exports **zero** symbols. On Linux with GCC, libstdc++
  template instantiations may still appear in the export list, as in
  zufft; they are accepted (R3; a version script needs a per-platform
  linker flag that portable `Makevars` cannot select). Measured in CI on
  2026-10-13 (kernel-matrix job, `R CMD INSTALL` of the whole package, R
  4.6.1, the toolchains' default flags):

  | Runner | Compiler | Install | Shared object | Exports |
  |---|---|---|---|---|
  | `macos-latest` (Apple M1) | Apple clang 21.0.0 | 7 s | 483 KB | `R_init_zuutf` |
  | `ubuntu-latest` (AMD EPYC 9V45) | GCC 13.3.0 | 17 s | 6.6 MB | `R_init_zuutf` |
  | `windows-latest` (Xeon Platinum 8573C) | GCC 14.3.0 (Rtools 4.5) | 26 s | 582 KB | `R_init_zuutf` |

  The Linux object is large because R's default `CXXFLAGS` there carry
  `-g`; R CMD check reports it as INFO ("installed size is 6.7Mb"), not a
  NOTE. The unoptimised gctorture build on GCC also exports
  `__gnu_cxx::char_traits<char>::eq` and `::length`, the libstdc++
  instantiations this section accepts.
- Static initialisation: simdutf's implementation singletons are
  function-local statics, initialised thread-safely on first use, so
  nothing runs at `dlopen` and nothing depends on initialisation order.
- The shared object exports `R_init_zuutf` only; the C table is
  registered there with `R_RegisterCCallable()`, which does not depend on
  export visibility (R3).
- Workflows (R5), all from `pedrobtz/r-actions`: `R-CMD-check.yaml`,
  `coverage.yaml` and `pkgdown.yaml` exist (*verified 2026-10-13*, this
  repository); Stage 1 adds `native-checks.yaml`, `vendor.yaml` and the
  `kernel-matrix` job, Stage 5 `consumer.yaml`, Stage 6 `hardening.yaml`.

---

## 13. Roadmap

| Stage | Title | Size |
| --- | --- | --- |
| 0 | Package identity: `DESCRIPTION`, licences, `.claude/CLAUDE.md`, check green | S |
| 1 | Vendor `v9.2.1` with manifest; `Makevars`; the shim and `zuutf_info()`; the workflow set and kernel matrix; the Windows go/no-go (§12.1); compile time, size and symbol audit on every leg | M |
| 2 | Validation, counts, error offsets and the condition classes | S |
| 3 | Conversion in every direction, the replacement loop, `NA`, BOM, UTF-32 byte order, detection | M |
| 4 | Base64: both alphabets, padding, forgiving and strict, line wrapping | S |
| 5 | The C table, the installed header and `tools/zuutftest` with `consumer.yaml` | S |
| 6 | Oracles (base R, zufast fixture), corpus, hostile input, fuzz targets, benchmarks recorded in §11 | M |
| 7 | v0.1.0 readiness: documentation, `cran-comments.md`, `pkg-cran-review`, release | S |

Exit criteria live in [roadmap.md](roadmap.md), which `pkg-roadmap`
writes from this table.

---

## 14. Acceptance criteria for v0.1.0

1. `R CMD check --as-cran` clean on every r-actions leg, Windows
   included, with §12.1's outcome recorded in that section.
2. Validation and conversion agree with base R and with zufast's fixture
   on the whole corpus and on random input, with every kernel the
   kernel-matrix job can force, and `zuutf_info()$kernel` proves which
   kernel ran.
3. Error offsets are exact and identical to zufast's scalar validator on
   every corpus file.
4. `tools/zuutftest` consumes every member of the C table and
   `consumer.yaml` is green with zuutf's `main` off the library path.
5. The §11 table has a measured number in every row.

---

## 15. Decisions

| # | Question | Decision, and why |
| --- | --- | --- |
| D1 | Home | Standalone, not `zufast` or `zubin`: zufast forbids compiled providers and C++; zubin has no text. |
| D2 | Library | simdutf, single-header release artefact, pinned at `v9.2.1`, every feature (the C API needs them all). |
| D3 | Glue language | C99 through `simdutf_c.h`; one C++17 shim for what the C API lacks (D10). |
| D4 | Windows | Gated by §12.1; per-kernel `-D` switches in `Makevars.win`, scalar fallback at worst. |
| D5 | Error policies | `error`, `replace` (WHATWG), `na`; `?` for Latin-1 targets. |
| D6 | Provider | A versioned registered table wrapping simdutf's C API, zuxml's rules; `Imports` + `LinkingTo` consumers. |
| D7 | Info function | `zuutf_info()`, the package name (R1). |
| D8 | Replacement | zuutf's own loop over `_with_errors` positions and `convert_valid_*` runs, so every pair has it; simdutf's `_with_replacement` used and cross-checked where it exists. |
| D9 | `SIMDUTF_NO_LIBCXX` | Not used: experimental, needs `-f` flags `Makevars` may not carry, and R links the C++ runtime anyway. |
| D10 | Kernel reporting and forcing | A forty-line `extern "C"` shim over `get_active_implementation()`; CI forces kernels with `SIMDUTF_FORCE_IMPLEMENTATION`. |
| D11 | Vendoring | The `singleheader.zip` release artefact with its SHA-256, zucrypt's manifest and scripts; no `amalgamate.py`, no patches. |
| D12 | Oracles | Base R in the CRAN suite; zufast through a CI-only fixture, never a `LinkingTo`; simdutf's `fallback` kernel against its SIMD kernels. |
| D13 | UTF-32 byte order | Both orders accepted; the non-native one byte-swapped in the glue, since the C API is native-only. |
| D14 | Base64 shape | One string or raw vector in, one out; `forgiving` maps to simdutf's `loose`/`strict` last-chunk handling plus zuutf's whitespace check in strict mode. |
| D15 | Name | `zuutf`, closed by creating this repository (RFC Q1). |
| D16 | The `fallback` kernel | Compiled on every platform with `-DSIMDUTF_IMPLEMENTATION_FALLBACK=1`, so the scalar oracle exists on arm64, where simdutf would otherwise omit it (§12.2; Stage 1, 2026-10-13). |
| D17 | Base64 prefix | `base64_encode()` and `base64_decode()`: the name users search for, and §3's prefix; decided by the maintainer in Stage 4 (2026-10-13), closing §16 Q1. |
| D18 | Either alphabet on decode | `url = NA` accepts both alphabets through `SIMDUTF_BASE64_DEFAULT_OR_URL`; decided by the maintainer in Stage 4 (2026-10-13), closing §16 Q4. |

---

## 16. Open questions

1. **`base64_` prefix.** Decided: `base64_` (D17, 2026-10-13).
2. **zufast's SIMD validator.** Should zufast still get its own
   header-only SIMD UTF-8 validator (§3.1) once zuutf exists?
   Recommended: only if a header-only consumer (one that cannot take a
   run-time dependency) asks. Blocks nothing here.
3. **Streaming.** A chunked converter that carries a split code point
   between calls is the enabler for connections and for a UTF-16
   `readLines()`; it is deferred until a consumer (`zucsv` reading
   UTF-16 exports is the likely one) asks. Blocks nothing in v0.1.0.
4. **`"either"` alphabet on decode.** Decided: `url = NA` (D18,
   2026-10-13).

---

## 17. What this design does not decide

- Whether `stringi` users should switch for validation and transcoding.
  zuutf does less than ICU, faster; both remain.
- Which family parsers adopt the C table. Each decides under R10.1.

Review prepared with assistance from generative AI.
