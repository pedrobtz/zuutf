# CLAUDE.md

<!-- markdownlint-disable-next-line MD013 -->
This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Shared conventions

The portfolio's shared rules are synced into `.claude/shared/` from
`pedrobtz/packages:claude/shared/`. Never edit them here. Where this file and
a shared file disagree, this file wins for this package.

@.claude/shared/workflow.md
@.claude/shared/r-package.md
@.claude/shared/ci.md
@.claude/shared/native-code.md
@.claude/shared/correctness.md
@.claude/shared/assurance.md

## What this is

`zuutf` is an R package that validates and converts text between UTF-8,
UTF-16 (LE and BE), UTF-32 (LE and BE) and Latin-1, counts characters,
detects encodings, and encodes and decodes Base64, through a vendored copy of
[simdutf](https://github.com/simdutf/simdutf) `v9.2.1`. Every validation and
conversion can report the 1-based offset of the first error in the input's
units. It is a *provider* in the `zu*` family: other packages call it from C
through a registered table, `zuutf_api_v1`. It has no hard runtime
dependency, and it owns no text semantics: no normalisation, case folding,
segmentation, or encodings beyond Latin-1 and the UTFs.

Two documents outrank this file. [.agents/design.md](.agents/design.md) is
the specification, numbered §1–§17: every statement in it is a decision, and
open questions live only in its §16. [.agents/roadmap.md](.agents/roadmap.md)
sequences it into Stages 0–7, each with exit criteria. Both were adopted on
2026-10-13 from
[RFC 0024](https://github.com/pedrobtz/packages/blob/main/rfcs/not-started/0024-zuutf-unicode-transcoding.md)
in `pedrobtz/packages`. `CLAUDE.md` orients, the design decides, the roadmap
sequences.

Sibling checkouts sit in `../`. `zucrypt` is the model for vendoring
(manifest and scripts), `zuxml` for the registered C table, `zufft` for
vendored C++ under CRAN's flag checks, and `zufast` is the CI-only oracle
(never a `LinkingTo`).

## Current state

**2026-11-11: Stages 0–7 done; Version 0.1.0, in `Pre-flight`, not yet on
CRAN.** simdutf 9.2.1 is vendored unmodified and runs every kernel on every
CI leg, Windows included (design §12.1: go). The whole §5 surface is
exported and documented, the C table `zuutf_api_v1` is consumed by
`tools/zuutftest`, and `hardening.yaml` runs the canaries, the fuzz targets
and the zufast oracle on every kernel. After Stage 7 the critical review
(#49–#51), the CRAN review (#53) and the fixes it led to (#55 strict
unpadded Base64url, #57 the unpadded-decode copy as an R vector) are merged.
What remains is the submission itself (issue #10), which is the maintainer's
decision, and #59 (gate the jobs that run on documentation-only pull
requests).

Update this paragraph at the end of every stage.

## Versions and dependents

The current version's parent issue is
[#1](https://github.com/pedrobtz/zuutf/issues/1) for `v0.1.0`, with the
stages #2–#9 (eight stages, 0 to 7) and the submission #10. Sibling packages that
depend on this one before CRAN does: none recorded yet; `tools/zuutftest` is
the in-repository consumer.

The C table in `inst/include/zuutf.h` (Stage 5) is ABI from the moment a
consumer links to it, even before 0.1.0: members are appended, never
reordered or removed (design §7).

## Commands

The shared commands are in `.claude/shared/r-package.md`. On top of them:

```sh
Rscript -e 'spelling::spell_check_package()'     # en-GB, inst/WORDLIST
Rscript tools/cran-suite-time.R                  # CRAN suite under 15 s
Rscript tools/kernel-matrix.R                    # suite once per kernel
Rscript tools/run-benchmarks.R [MB]              # design §11, not a gate
tools/run-fuzz [validate convert base64]         # libFuzzer, needs clang
R CMD INSTALL tools/zuutftest                    # consumer, after zuutf
```

- `tools/vendor/{fetch,apply,verify}` re-vendor and verify simdutf against
  `tools/vendor/manifest.tsv` and `checksums.sha256`.
- `tools/fixtures/` regenerates the test fixtures; `tools/zuutforacle` is
  the CI-only zufast oracle; `tools/fuzz/` holds the targets, seeds and
  canaries.
- `SIMDUTF_FORCE_IMPLEMENTATION=<kernel>` set before R starts forces a
  simdutf kernel (design §10).
- `tools/run-fuzz` on macOS needs `CC=/opt/homebrew/opt/llvm/bin/clang`
  (Apple's clang has no libFuzzer); `CANARY_ONLY=1` only proves each canary
  crashes.

## Architecture

Layout, from design §4. `zut_input.c` reads elements, strips BOMs and owns
the scratch; `zut_view.c` sees one element as code units (aligned, UTF-32 in
native order) and does every run-level operation (validate, count, length,
write, the maximal subpart); `zut_validate.c`, `zut_count.c` and
`zut_convert.c` loop over elements. `zut_base64.c` wraps simdutf's Base64.

<!-- markdownlint-disable MD013 -->
```text
R/            argument handling, encoding names, the invalid= policy, conditions
src/          init.c              registration, and the C table (Stage 5)
              zut_*.c             C99 glue over simdutf_c.h: validate, count, convert, base64
              zut_impl.cpp        the one C++17 shim: kernel names, forcing (D10)
              vendor/simdutf/     simdutf.h, simdutf.cpp, simdutf_c.h, unmodified
inst/include/ zuutf.h             the public C table (Stage 5)
tools/        vendor/ scripts and manifest; consumer and oracle fixtures
```
<!-- markdownlint-enable MD013 -->

R validates arguments and picks the encoding; C loops over elements and
calls simdutf's C API; R raises the classed condition.

## Invariants that are easy to break

- **No compiler flags beyond CRAN's.** `PKG_*FLAGS` carry `$(C_VISIBILITY)`,
  `$(CXX_VISIBILITY)` and `-I`/`-D` only; any `-m*`, `-f*`, `-O*` or `-std*`
  token is an R CMD check WARNING. simdutf selects kernels with target
  attributes, so no `-mavx2` is needed (design §12.2).
- **The shared object exports `R_init_zuutf` only** (R3). Keep
  `attribute_visible` on it and visibility macros in `Makevars`.
- **The vendored tree is upstream, byte for byte.** No patches (D11);
  `tools/vendor/verify` checks the SHA-256. A new simdutf release is a
  re-vendor, not an edit.
- **No R API call between a simdutf call and the use of its result**, and no
  R error through a C++ frame. `R_CheckUserInterrupt()` runs between
  elements only.
- **Output is sized by simdutf's length functions and allocated once**; a
  `_safe` variant with explicit capacity is used wherever the C API has one.
- **Offsets are 1-based, in the input's units, after any BOM.**
- **`SIMDUTF_FORCE_IMPLEMENTATION` is trusted by simdutf without a CPU
  check.** A compiled-in kernel the processor lacks dies of SIGILL on first
  use; `check_kernel()` in `R/conditions.R` must run before every `.Call`
  that reaches simdutf.
- **Never type `\u` escapes through the tools as text to be written.** They
  have arrived as literal characters before; build them in a script
  (`chr(92)`), and keep R sources and tests ASCII outside comments.
- **The C table's header includes `<stddef.h>` and `<stdint.h>` only** and
  must compile standalone as C99 and C++17.
- **A change to a decision amends the design in the same commit.**

## Naming

<!-- markdownlint-disable MD013 -->
| Layer | Prefix | Examples |
| --- | --- | --- |
| R exports | `utf_`, `base64_`, plus `zuutf_info()` | `utf_valid()`, `base64_decode()` |
| R condition classes | `zuutf_` | `zuutf_error`, `zuutf_encoding_error` |
| Public C | `zuutf_` / `ZUUTF_` | `zuutf_api`, `ZUUTF_API_HAS()` |
| Internal C | `zut_` / `ZUT_` | `zut_force_kernel()` |
| Test switches | `ZUUTF_` | `ZUUTF_SKIP_HEAVY`, `ZUUTF_SLOW_TESTS`, `ZUUTF_TIMING_TESTS` |
<!-- markdownlint-enable MD013 -->

## Editing rules

These add to, or deviate from, `.claude/shared/r-package.md`:

- **There is no `README.Rmd`; edit `README.md` directly.**
- Prose is en-GB (`Language: en-GB`, `inst/WORDLIST`); run the spelling
  check after prose changes.
- Every exported function has `@return` and runnable `@examples`.

## Testing

- **Assert on condition classes and their fields (`index`, `offset`,
  `encoding`)**, never message text; wording is in snapshot tests
  (`tests/testthat/_snaps`).
- **Oracles before hand-written cases.** Base R's `validUTF8()`, `iconv()`
  and `utf8ToInt()` in the CRAN suite; Markus Kuhn's stress test and the
  WHATWG Base64 vectors as fixtures with provenance in
  `tests/testthat/fixtures/MANIFEST.tsv`; zufast in the CI-only
  `tools/zuutforacle`; simdutf's `fallback` kernel against its SIMD kernels
  through the kernel matrix (design §10).
- **Helpers.** `helper-bytes.R` builds byte strings from UTF-8 text with
  `iconv()` or from hex; `helper-kernels.R` has `for_each_kernel()`, which
  forces each supported kernel in-process and restores the previous one;
  `helper-skip.R` reads the test switches; `helper-symbols.R` reads the
  installed shared object's symbol table (`nm`, or `objdump -p` on Windows)
  for `test-abi.R` and `test-vendor.R`.
- **Test switches** (alignment rule R7, design §10): `ZUUTF_SKIP_HEAVY=true`
  shrinks the random sweeps to what reaches every path (native-checks sets
  it for gctorture); `ZUUTF_SLOW_TESTS=true` widens them and runs them on
  every kernel in-process; `ZUUTF_TIMING_TESTS=true` runs the assertions on
  elapsed time.
- **Runtime:** the CRAN suite stays under 15 s (`tools/cran-suite-time.R`);
  heavy tests go behind `ZUUTF_SLOW_TESTS`.
- Run `gctorture(TRUE)` over the code a C change touches.

## Continuous integration

Shared workflows from `pedrobtz/r-actions`, pinned at `@v1`:

- `R-CMD-check.yaml` calls `r-cmd-check.yml` with the default runners plus
  Windows R-devel (CRAN's r-devel-windows-x86_64 flavour) and
  `nosuggests: true`. **Deviation from `ci.md`:** its profile is quick on
  pull requests and full on pushes to `main` and under the `full-ci` label,
  rather than `profile: auto`.
- `native-checks.yaml`: sanitizers, valgrind, LTO, gctorture, rchk,
  analyzers and the CRAN special flavours.
- `coverage.yaml`, `vendor.yaml`, and `fuzz.yml` from `hardening.yaml`.

The package's own workflows (design §10, §12):

- `kernel-matrix.yaml`: the suite once per simdutf kernel each runner
  supports, on Linux, Windows (the §12.1 go/no-go) and macOS, plus install
  time, object size, the export list, the 15-second CRAN-suite check and the
  slow sweeps.
- `consumer.yaml`: `tools/zuutftest` installed from outside the source tree
  against the installed header, which is also compiled standalone as C99 and
  C++17 under `-Werror` (alignment rule R10.4).
- `hardening.yaml`: canaries, libFuzzer (five minutes a target on pull
  requests and pushes, an hour nightly and on dispatch) and the zufast
  oracle on every kernel.
- `benchmarks.yaml`: on dispatch or the `benchmarks` label only; not a gate.
- `pkgdown.yaml`: the site.

## Vendored native code

simdutf, MIT option of its Apache-2.0/MIT dual licence, pinned at `v9.2.1`
from the `singleheader.zip` release artefact (design §8). The manifest,
checksum and scripts live in `tools/vendor/`; the licence in
`inst/COPYRIGHTS` and `LICENSE.note`, and `Authors@R` lists every copyright
holder the tarball bundles, the PyTorch CPU-detection authors included.

**Deviation from `native-code.md`:** there are no local patches and no
`tools/patches/`. simdutf as vendored already satisfies CRAN's compiled-code
check, and `test-vendor.R` checks that the installed object references none
of `printf`, `abort`, `exit` or `stderr`. If an upstream bump brings one
back, that is when a patch is needed, and D11 changes with it.
