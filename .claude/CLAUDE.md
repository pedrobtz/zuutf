# CLAUDE.md

<!-- markdownlint-disable-next-line MD013 -->
This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`zuutf` is an R package that validates and converts text between UTF-8, UTF-16 (LE and BE), UTF-32 (LE and BE) and Latin-1, counts characters, detects encodings, and encodes and decodes Base64, through a vendored copy of [simdutf](https://github.com/simdutf/simdutf) `v9.2.1`. Every validation and conversion can report the 1-based offset of the first error in the input's units. It is a *provider* in the `zu*` family: other packages call it from C through a registered table, `zuutf_api_v1`. It has no hard runtime dependency, and it owns no text semantics: no normalisation, case folding, segmentation, or encodings beyond Latin-1 and the UTFs.

Two documents outrank this file. [.agents/design.md](../.agents/design.md) is the specification, numbered §1–§17: every statement in it is a decision, and open questions live only in its §16. [.agents/roadmap.md](../.agents/roadmap.md) sequences it into Stages 0–7, each with exit criteria. Both were adopted on 2026-10-13 from [RFC 0024](https://github.com/pedrobtz/packages/blob/main/rfcs/not-started/0024-zuutf-unicode-transcoding.md) in `pedrobtz/packages`. `CLAUDE.md` orients, the design decides, the roadmap sequences.

Sibling checkouts sit in `../`. `zucrypt` is the model for vendoring (manifest and scripts), `zuxml` for the registered C table, `zufft` for vendored C++ under CRAN's flag checks, and `zufast` is the CI-only oracle (never a `LinkingTo`).

## Current state

**2026-10-13: Stages 0–7 done; Version 0.1.0, in `Pre-flight`.** simdutf 9.2.1 is vendored unmodified and runs every kernel on every CI leg, Windows included (design §12.1: go). The whole §5 surface is exported and documented, the C table `zuutf_api_v1` is consumed by `tools/zuutftest`, and `hardening.yaml` runs the canaries, the fuzz targets and the zufast oracle on every kernel. What remains is the submission itself (issue #10), which is the maintainer's decision. Tracking: parent [#1](https://github.com/pedrobtz/zuutf/issues/1), stages #2–#9, submission #10.

Update this paragraph at the end of every stage.

## Stage tracking

Progress toward the next version is tracked as GitHub sub-issues, so the parent issue shows a progress bar such as "6 of 8".

- **One parent issue per target version**, `v0.1.0`: #1.
- **One sub-issue per roadmap stage**, titled as the roadmap titles it, for example `Stage 3 — Conversion`, linking to that section. The roadmap has eight stages, 0 to 7.
- **Every tracking issue carries the `stage` label.**
- **Close a stage by merging its pull request.** Put `Closes #<n>` in the body. Never close a stage whose exit criteria are not met; record a deviation in the roadmap first.
- **The roadmap stays authoritative.** Adding, removing or renaming a stage means editing the roadmap and the sub-issues in the same change.
- Close the parent issue when CRAN accepts the version and it is tagged.

## Versioning

The package develops at `0.0.0.9000` and targets `0.1.0` for its first CRAN release. Set `Version: 0.1.0` and the matching `NEWS.md` heading when the package enters `Pre-flight` (Stage 7). Bump to `0.1.0.9000` only after CRAN accepts it.

Until the first release the R API may change freely. The C table in `inst/include/zuutf.h` (Stage 5) is ABI from the moment a consumer links to it: members are appended, never reordered or removed (design §7).

## Commands

Run from the package root.

```sh
Rscript -e 'devtools::load_all()'                # compile src/ and load
Rscript -e 'devtools::document()'                # roxygen -> NAMESPACE, man/
Rscript -e 'devtools::test()'                    # full testthat suite
Rscript -e 'devtools::test(filter = "<name>")'   # one test file
Rscript -e 'devtools::test(shuffle = TRUE)'      # order independence
Rscript -e 'devtools::check()'                   # R CMD check
Rscript -e 'spelling::spell_check_package()'     # en-GB, inst/WORDLIST
air format .                                     # format R sources
```

Scripts and fixtures: `tools/vendor/{fetch,apply,verify}`; `tools/kernel-matrix.R`; `tools/fixtures/` (regenerates the test fixtures); `tools/zuutftest` (the consumer fixture: `R CMD INSTALL tools/zuutftest` after installing zuutf); `tools/zuutforacle` and `tools/run-benchmarks` arrive in Stage 6. `SIMDUTF_FORCE_IMPLEMENTATION=<kernel>` set before R starts forces a simdutf kernel (design §10).

## Architecture

Layout, from design §4. `zut_input.c` reads elements, strips BOMs and owns the scratch; `zut_view.c` sees one element as code units (aligned, UTF-32 in native order) and does every run-level operation (validate, count, length, write, the maximal subpart); `zut_validate.c`, `zut_count.c` and `zut_convert.c` loop over elements. `zut_base64.c` wraps simdutf's Base64.

```text
R/            argument handling, encoding names, the invalid= policy, conditions
src/          init.c              registration, and the C table (Stage 5)
              zut_*.c             C99 glue over simdutf_c.h: validate, count, convert, base64
              zut_impl.cpp        the one C++17 shim: kernel names, forcing (D10)
              vendor/simdutf/     simdutf.h, simdutf.cpp, simdutf_c.h, unmodified
inst/include/ zuutf.h             the public C table (Stage 5)
tools/        vendor/ scripts and manifest; consumer and oracle fixtures
```

R validates arguments and picks the encoding; C loops over elements and calls simdutf's C API; R raises the classed condition.

## Invariants that are easy to break

- **No compiler flags beyond CRAN's.** `PKG_*FLAGS` carry `$(C_VISIBILITY)`, `$(CXX_VISIBILITY)` and `-I`/`-D` only; any `-m*`, `-f*`, `-O*` or `-std*` token is an R CMD check WARNING. simdutf selects kernels with target attributes, so no `-mavx2` is needed (design §12.2).
- **The shared object exports `R_init_zuutf` only** (R3). Keep `attribute_visible` on it and visibility macros in `Makevars`.
- **The vendored tree is upstream, byte for byte.** No patches (D11); `tools/vendor/verify` checks the SHA-256. A new simdutf release is a re-vendor, not an edit.
- **No R API call between a simdutf call and the use of its result**, and no R error through a C++ frame. `R_CheckUserInterrupt()` runs between elements only.
- **Output is sized by simdutf's length functions and allocated once**; a `_safe` variant with explicit capacity is used wherever the C API has one.
- **Offsets are 1-based, in the input's units, after any BOM.**
- **`SIMDUTF_FORCE_IMPLEMENTATION` is trusted by simdutf without a CPU check.** A compiled-in kernel the processor lacks dies of SIGILL on first use; `check_kernel()` in `R/conditions.R` must run before every `.Call` that reaches simdutf.
- **Never type `\u` escapes through the tools as text to be written.** They have arrived as literal characters before; build them in a script (`chr(92)`), and keep R sources and tests ASCII outside comments.
- **The C table's header includes `<stddef.h>` and `<stdint.h>` only** and must compile standalone as C99 and C++17.

## Naming

| Layer | Prefix | Examples |
|---|---|---|
| R exports | `utf_`, `base64_`, plus `zuutf_info()` | `utf_valid()`, `base64_decode()` |
| R condition classes | `zuutf_` | `zuutf_error`, `zuutf_encoding_error` |
| Public C | `zuutf_` / `ZUUTF_` | `zuutf_api`, `ZUUTF_API_HAS()` |
| Internal C | `zut_` / `ZUT_` | `zut_force_kernel()` |
| Test switches | `ZUUTF_` | `ZUUTF_SKIP_HEAVY`, `ZUUTF_SLOW_TESTS`, `ZUUTF_TIMING_TESTS` |

## Testing conventions

- **Self-sufficient.** Every test builds its own inputs inside the `test_that()` block. No file-scope objects.
- **Self-contained.** Global state goes through `withr::local_*()`, randomised input through `withr::local_seed()`. Tests write only under `tempdir()`.
- **Assert on condition classes and fields (`index`, `offset`, `encoding`), never message text.**
- **Order independence.** `devtools::test(shuffle = TRUE)` is part of the definition of done.
- **Oracles before hand-written cases.** Base R's `validUTF8()`, `iconv()` and `utf8ToInt()` in the CRAN suite; Markus Kuhn's stress test and the WHATWG Base64 vectors as fixtures with provenance in `tests/testthat/fixtures/MANIFEST.tsv`; zufast in the CI-only `tools/zuutforacle`; simdutf's `fallback` kernel against its SIMD kernels through the kernel matrix (design §10).
- **Keep the suite inside the CRAN time budget:** under 15 s; heavy tests behind `ZUUTF_SLOW_TESTS`.

## Definition of done

`devtools::document()` and `devtools::check()` clean, meaning 0 errors, 0 warnings and 0 notes. The one allowed note is "New submission" before the first release. `devtools::test(shuffle = TRUE)` green. `gctorture(TRUE)` clean when C changed. CI green on every leg. A user-facing change also needs a test, roxygen documentation and a `NEWS.md` entry. A change to a decision amends the design in the same commit.

## Releasing to CRAN

- **CI is the pre-submission check.** The `pedrobtz/r-actions` R CMD check runs `--as-cran` on the CRAN-like runners and containers, and replaces win-builder, the macOS builder and R-hub. `cran-comments.md` lists the CI legs as its test environments.
- **Entering `Pre-flight`.** Stages 0–6 done, `Version: 0.1.0` with the `NEWS.md` heading, `cran-comments.md` written, CI green.
- **Before submitting,** run the `pkg-cran-review` skill and resolve every finding.
- **The pretest is automated and does not read `cran-comments.md`.** Fix every NOTE rather than justifying it.
- **After acceptance,** tag `v0.1.0`, publish the GitHub release, bump to `0.1.0.9000`, and close the parent issue.

## Editing rules

- roxygen comments are the source. Never edit `man/` or `NAMESPACE` by hand.
- There is no `README.Rmd`; edit `README.md` directly.
- Prose is simple, short and en-GB (`Language: en-GB`, `inst/WORDLIST`).
- Wrap roxygen at 80 characters; `air format .` on R sources.
- No hard runtime dependency; add none without a recorded decision.
- Export and document public functions, each with `@return` and runnable `@examples`. No roxygen topics for internals.

## Continuous integration

Workflows come from `pedrobtz/r-actions`, pinned at `@v1`. `R-CMD-check.yaml` (quick on pull requests, full on `main` and under the `full-ci` label), `coverage.yaml` and `pkgdown.yaml` exist. Stage 1 adds `vendor.yaml`, `native-checks.yaml` and the `kernel-matrix` job; Stage 5 `consumer.yaml`; Stage 6 `hardening.yaml` (design §12.2).

This file lives in `.claude/`, not the package root, because pkgdown renders every root-level `*.md` as a site page (alignment rule R8 in `pedrobtz/packages`); keep it here.

## Vendored native code

simdutf, MIT option of its Apache-2.0/MIT dual licence, pinned at `v9.2.1` from the `singleheader.zip` release artefact (design §8). The manifest, checksum and scripts live in `tools/vendor/`; the licence in `inst/COPYRIGHTS` and `LICENSE.note`. CRAN's compiled-code check applies to vendored code too: the installed object must reference none of `printf`, `abort`, `exit` or `stderr`, and `test-vendor.R` checks it.

## Commits and pull requests

Short, imperative, sentence-case commit subjects, optionally scoped. Keep each commit focused and do not sweep in unrelated files. A pull request explains the user-visible outcome and the rationale, links related issues, lists the checks that were run and the tests that were skipped, and flags platform-sensitive or vendored changes. Performance claims need evidence.

Never commit or push to the default branch. Work on a branch (`stage-N-<slug>`), open a pull request, and leave it for review. Do not merge a pull request unless you are told to.

When you find a defect, in this package or in an upstream tool, open an issue for it rather than only working around it.
