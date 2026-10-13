## Submission

This is the first submission of zuutf.

zuutf bundles simdutf 9.2.1 (https://github.com/simdutf/simdutf),
unmodified, under its MIT licence option; inst/COPYRIGHTS and LICENSE.note
name its authors and give the licence, and Authors@R lists them as
copyright holders.

## Test environments

The checks run on GitHub Actions through pedrobtz/r-actions, with
`R CMD check --as-cran`:

* macOS (latest runner, arm64), R release
* Windows (latest runner, x86-64, Rtools 4.5), R release
* Ubuntu (latest runner), R release and R oldrel-1
* R-hub containers for CRAN's r-devel Linux flavours: clang23 and
  ubuntu-clang (with CRAN's -std=gnu23 -pedantic), and ubuntu-gcc16
* UBSan (gcc and clang), ASan (gcc and clang), valgrind, LTO, gctorture,
  rchk, -fanalyzer, and the rcnst, rlibro and vnu special checks

## R CMD check results

0 errors | 0 warnings | 0 notes on every leg above, apart from the
"New submission" note.

On Linux, the installed size is reported as INFO (about 7 MB, almost all
of it libs/): the compiled simdutf object carries debugging symbols from
R's default `-g`. The source tarball is under 1 MB.

## Windows

simdutf documents MinGW GCC as unsupported. Every simdutf kernel the CI
runners support (AVX-512 "icelake", AVX2 "haswell", SSE4.2 "westmere" and
the scalar fallback) was forced in turn on Windows and passed the whole test
suite and an oracle comparison with an independent scalar validator, so no
kernel is disabled.
