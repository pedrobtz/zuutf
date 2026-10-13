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
