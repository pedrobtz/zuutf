// The one C++ file (design §4, D10). simdutf's C API has no implementation
// selection, so this wraps get_active_implementation() and
// get_available_implementations() behind extern "C" functions that return
// only const char * and int.
//
// Names and descriptions are returned as string_view::data(). simdutf
// builds every implementation's name and description from a string literal,
// so the pointer is NUL-terminated and lives as long as the library.

#include "simdutf.h"
#include "zut_impl.h"

#include <cstring>

#include "simdutf_c.h"
#include "zuutf.h"

// The installed header mirrors simdutf's error codes (design §7); a
// re-vendor that renumbers them fails here, not in a consumer.
static_assert(ZUUTF_ERR_SUCCESS == SIMDUTF_ERROR_SUCCESS, "ZUUTF_ERR_SUCCESS");
static_assert(ZUUTF_ERR_HEADER_BITS == SIMDUTF_ERROR_HEADER_BITS, "ZUUTF_ERR_HEADER_BITS");
static_assert(ZUUTF_ERR_TOO_SHORT == SIMDUTF_ERROR_TOO_SHORT, "ZUUTF_ERR_TOO_SHORT");
static_assert(ZUUTF_ERR_TOO_LONG == SIMDUTF_ERROR_TOO_LONG, "ZUUTF_ERR_TOO_LONG");
static_assert(ZUUTF_ERR_OVERLONG == SIMDUTF_ERROR_OVERLONG, "ZUUTF_ERR_OVERLONG");
static_assert(ZUUTF_ERR_TOO_LARGE == SIMDUTF_ERROR_TOO_LARGE, "ZUUTF_ERR_TOO_LARGE");
static_assert(ZUUTF_ERR_SURROGATE == SIMDUTF_ERROR_SURROGATE, "ZUUTF_ERR_SURROGATE");
static_assert(ZUUTF_ERR_INVALID_BASE64_CHARACTER == SIMDUTF_ERROR_INVALID_BASE64_CHARACTER,
              "ZUUTF_ERR_INVALID_BASE64_CHARACTER");
static_assert(ZUUTF_ERR_BASE64_INPUT_REMAINDER == SIMDUTF_ERROR_BASE64_INPUT_REMAINDER,
              "ZUUTF_ERR_BASE64_INPUT_REMAINDER");
static_assert(ZUUTF_ERR_BASE64_EXTRA_BITS == SIMDUTF_ERROR_BASE64_EXTRA_BITS,
              "ZUUTF_ERR_BASE64_EXTRA_BITS");
static_assert(ZUUTF_ERR_OUTPUT_BUFFER_TOO_SMALL == SIMDUTF_ERROR_OUTPUT_BUFFER_TOO_SMALL,
              "ZUUTF_ERR_OUTPUT_BUFFER_TOO_SMALL");
static_assert(ZUUTF_ERR_OTHER == SIMDUTF_ERROR_OTHER, "ZUUTF_ERR_OTHER");

namespace {

const simdutf::implementation *kernel_at(int i) {
  const auto &list = simdutf::get_available_implementations();
  if (i < 0 || static_cast<size_t>(i) >= list.size()) {
    return nullptr;
  }
  return *(list.begin() + i);
}

} // namespace

extern "C" {

const char *zut_simdutf_version(void) { return SIMDUTF_VERSION; }

const char *zut_active_kernel(void) {
  return simdutf::get_active_implementation()->name().data();
}

int zut_active_kernel_ok(void) {
  const simdutf::implementation *impl = simdutf::get_active_implementation();
  return impl->name() != "unsupported" && impl->supported_by_runtime_system();
}

int zut_kernel_count(void) {
  return static_cast<int>(simdutf::get_available_implementations().size());
}

const char *zut_kernel_name(int i) {
  const simdutf::implementation *impl = kernel_at(i);
  return impl ? impl->name().data() : "";
}

const char *zut_kernel_description(int i) {
  const simdutf::implementation *impl = kernel_at(i);
  return impl ? impl->description().data() : "";
}

int zut_kernel_supported(int i) {
  const simdutf::implementation *impl = kernel_at(i);
  return impl && impl->supported_by_runtime_system() ? 1 : 0;
}

int zut_force_kernel(const char *name) {
  const simdutf::implementation *impl =
      simdutf::get_available_implementations()[name];
  if (impl == nullptr || !impl->supported_by_runtime_system()) {
    return 0;
  }
  simdutf::get_active_implementation() = impl;
  return 1;
}

} // extern "C"
