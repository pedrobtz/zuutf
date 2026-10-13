# Information about the bundled simdutf library

Reports the version of simdutf compiled into zuutf, the kernel in use,
and every kernel compiled in with whether this processor can run it.

## Usage

``` r
zuutf_info()
```

## Value

A list with elements:

- `simdutf`:

  The simdutf version, as a string.

- `kernel`:

  The name of the kernel in use.

- `kernels`:

  A data frame with one row per kernel compiled in and columns `name`,
  `description` and `supported` (whether this processor can run it).

## Details

simdutf picks the most advanced kernel the processor supports the first
time any function needs one: on x86-64 `"icelake"` (AVX-512),
`"haswell"` (AVX2) or `"westmere"` (SSE4.2), on ARM64 `"arm64"` (NEON),
and `"fallback"`, plain C++, everywhere. Setting the environment
variable `SIMDUTF_FORCE_IMPLEMENTATION` to a kernel name before R starts
makes simdutf use that kernel instead; an unknown name, or one this
processor cannot run, gives `"unsupported"`, and every function then
fails.

## Examples

``` r
info <- zuutf_info()
info$simdutf
#> [1] "9.2.1"
info$kernel
#> [1] "haswell"
info$kernels
#>       name
#> 1  icelake
#> 2  haswell
#> 3 westmere
#> 4 fallback
#>                                                               description
#> 1 Intel AVX512 (AVX-512BW, AVX-512CD, AVX-512VL, AVX-512VBMI2 extensions)
#> 2                                                          Intel/AMD AVX2
#> 3                                                        Intel/AMD SSE4.2
#> 4                                         Generic fallback implementation
#>   supported
#> 1     FALSE
#> 2      TRUE
#> 3      TRUE
#> 4      TRUE
```
