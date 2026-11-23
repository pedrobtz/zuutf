You are hunting for wrong-result bugs in the R package at /private/tmp/claude-501/-Users-pbtz-src-github-com-pedrobtz/432a5e20-13bd-4b69-acab-05b86173939e/scratchpad/hunt-codex/src
(installed in /private/tmp/claude-501/-Users-pbtz-src-github-com-pedrobtz/432a5e20-13bd-4b69-acab-05b86173939e/scratchpad/hunt-codex/lib; put `.libPaths("/private/tmp/claude-501/-Users-pbtz-src-github-com-pedrobtz/432a5e20-13bd-4b69-acab-05b86173939e/scratchpad/hunt-codex/lib")` first in every Rscript). You are one of several independent hunters; report only what you establish yourself.

The package is zuutf: UTF-8/16/32 and Latin-1 validation, conversion, counting and detection, plus Base64, on the vendored simdutf 9.2.1. Exports: utf_valid, utf_error_at, utf_is_ascii, utf_count, utf_length_as, utf_convert, utf_decode, utf_encode, utf_detect, base64_encode, base64_decode, zuutf_info; plus a C table zuutf_api_v1 for other packages (inst/include, src/zut_api.c; tools/zuutftest is a consumer package you may build into /private/tmp/claude-501/-Users-pbtz-src-github-com-pedrobtz/432a5e20-13bd-4b69-acab-05b86173939e/scratchpad/hunt-codex/lib). The specification is .agents/design.md with the roxygen in R/. Behaviour the design records as deliberate is not a bug: say "by design" with the citation. This machine's Rscript defaults to the C locale; use LC_ALL=en_US.UTF-8 unless the locale is what you test. Kernels on this machine: haswell, westmere, fallback (force with SIMDUTF_FORCE_IMPLEMENTATION=<name> before R starts).

Your slice: the whole package. Target map:
- Boundaries: UTF-8 validation and error offsets; UTF-16LE/BE and UTF-32LE/BE decoding; Latin-1/ASCII; encoding to every target; U+FFFD replacement (WHATWG maximal subpart); BOM handling and "auto"/"UTF-16"/"UTF-32" detection; marked-encoding character input and useBytes; counts (utf_count, utf_length_as); Base64 strict/forgiving, standard/url/either, padded/unpadded, line_length; the C table.
- Limits: line_length >= 4 (asReal cast to size_t); Base64 text <= INT_MAX characters; converted string <= 2^31-1 bytes; as_count() switching integer/double at .Machine$integer.max.
- Numbers into C: encoding/from/to codes, policy, mode, Base64 options, line_length, url, pad, forgiving, useBytes.
- Platform branches: the kernels above.

Method. Read the code only as far as you need to form hypotheses, then test them by running the package from Rscript against inputs you build byte by byte. Use independent oracles: iconv(), validUTF8(), nchar(), utf8ToInt(); Python 3 (codecs with errors="replace", base64 module); Node if present (TextDecoder, atob). Work under /private/tmp/claude-501/-Users-pbtz-src-github-com-pedrobtz/432a5e20-13bd-4b69-acab-05b86173939e/scratchpad/hunt-codex/hunt/ and keep every script. Temporary files only; change nothing under /private/tmp/claude-501/-Users-pbtz-src-github-com-pedrobtz/432a5e20-13bd-4b69-acab-05b86173939e/scratchpad/hunt-codex/src, and nothing outside /private/tmp/claude-501/-Users-pbtz-src-github-com-pedrobtz/432a5e20-13bd-4b69-acab-05b86173939e/scratchpad/hunt-codex.

Probes, for every target:
1. The other side: compare output bytes with an independent implementation.
2. Straddle: each constant at limit - 1, limit, limit + 1 (SIMD block edges 16/32/64, BOM lengths, odd lengths, line_length).
3. Equivalent inputs: the same payload by two routes (raw vs list vs character, with/without BOM, auto vs explicit, url = NA vs explicit, kernels) must agree.
4. Sequences: kernel switching, large call after small.
5. Before the error: the condition's index, offset and encoding fields against the documentation.
6. Numbers: NA, zero, negative, fraction, .Machine$integer.max + 1, Inf, NaN, zero-length on every numeric argument.
7. The second case: repeated BOMs, a BOM of another encoding, end-of-input with two kinds of incompleteness, characters in R strings that look like byte-level markers.
8. A hostile session: LC_ALL=C, a Latin-1 locale, options(OutDec = ",", scipen = -5, digits = 3, warn = 2), non-UTC TZ.
9. Documentation as the specification: each roxygen sentence that states behaviour is a claim; test it. Check error messages against the function's actual arguments.

Also say what a careful user would be surprised by, even if you cannot name a rule it breaks.

Budget. Spend effort running probes, not reading. Stop when the map is covered or your last ten probes all held.

Report, and nothing else:
- Findings. Each: a one-line title; file:line; the exact trigger (R code); what was observed and what the specification, documentation or design says instead; reproduced or inspection; the cause, if found; the script path.
- Held. Probes that found nothing, one line each.
- Not reached. Targets not probed, and why.
