#' Information about the bundled simdutf library
#'
#' Reports the version of simdutf compiled into zuutf, the kernel in use,
#' and every kernel compiled in with whether this processor can run it.
#'
#' simdutf picks the most advanced kernel the processor supports the first
#' time any function needs one: on x86-64 `"icelake"` (AVX-512),
#' `"haswell"` (AVX2) or `"westmere"` (SSE4.2), on ARM64 `"arm64"` (NEON),
#' and `"fallback"`, plain C++, everywhere. Setting the environment variable
#' `SIMDUTF_FORCE_IMPLEMENTATION` to a kernel name before R starts makes
#' simdutf use that kernel instead; an unknown name, or one this processor
#' cannot run, gives `"unsupported"`, and every function then fails.
#'
#' @return A list with elements:
#'   * `simdutf`: the simdutf version, as a string.
#'   * `kernel`: the name of the kernel in use.
#'   * `kernels`: a data frame with one row per kernel compiled in and
#'     columns `name`, `description` and `supported` (whether this
#'     processor can run it).
#' @export
#' @examples
#' info <- zuutf_info()
#' info$simdutf
#' info$kernel
#' info$kernels
zuutf_info <- function() {
  res <- .Call(zut_info)
  list(
    simdutf = res$simdutf,
    kernel = res$kernel,
    kernels = data.frame(
      name = res$name,
      description = res$description,
      supported = res$supported,
      stringsAsFactors = FALSE
    )
  )
}

# Make the named kernel active in this process, for tests (design §10).
# Returns FALSE, leaving the kernel unchanged, when the name is not compiled
# in or the processor cannot run it.
.zut_force_kernel <- function(name) {
  stopifnot(is.character(name), length(name) == 1L, !is.na(name))
  .Call(zut_force_kernel, name)
}
