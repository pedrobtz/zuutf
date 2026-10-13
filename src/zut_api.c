/* The registered C table, zuutf_api_v1 (design §7). Every member is a pure
 * function over simdutf's C API: no R call, no allocation, no write past
 * the capacity it is given. */
#include <stddef.h>
#include <string.h>

#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>

#include "simdutf_c.h"
#include "zut_api.h"
#include "zut_base64.h"
#include "zut_impl.h"
#include "zuutf.h"

static zuutf_result ok(size_t count) {
  zuutf_result r = {ZUUTF_ERR_SUCCESS, count};
  return r;
}

static zuutf_result from_simdutf(simdutf_result s) {
  zuutf_result r = {(int) s.error, s.count};
  return r;
}

static zuutf_result too_small(size_t need) {
  zuutf_result r = {ZUUTF_ERR_OUTPUT_BUFFER_TOO_SMALL, need};
  return r;
}

#define U16(p) ((const char16_t *) (const void *) (p))
#define U32(p) ((const char32_t *) (const void *) (p))

static zuutf_result api_validate_utf8(const char *s, size_t n) {
  return from_simdutf(simdutf_validate_utf8_with_errors(s, n));
}

static zuutf_result api_validate_utf16le(const uint16_t *s, size_t n) {
  return from_simdutf(simdutf_validate_utf16le_with_errors(U16(s), n));
}

static zuutf_result api_validate_utf32(const uint32_t *s, size_t n) {
  return from_simdutf(simdutf_validate_utf32_with_errors(U32(s), n));
}

static int api_validate_ascii(const char *s, size_t n) {
  return simdutf_validate_ascii(s, n) ? 1 : 0;
}

static size_t api_count_utf8(const char *s, size_t n) {
  return simdutf_count_utf8(s, n);
}

static size_t api_utf8_length_from_utf16le(const uint16_t *s, size_t n) {
  return simdutf_utf8_length_from_utf16le(U16(s), n);
}

static size_t api_utf16_length_from_utf8(const char *s, size_t n) {
  return simdutf_utf16_length_from_utf8(s, n);
}

static zuutf_result api_utf16le_to_utf8(const uint16_t *s, size_t n, char *out,
                                        size_t cap) {
  simdutf_result v = simdutf_validate_utf16le_with_errors(U16(s), n);
  if (v.error != SIMDUTF_ERROR_SUCCESS) {
    return from_simdutf(v);
  }
  size_t need = simdutf_utf8_length_from_utf16le(U16(s), n);
  if (need > cap) {
    return too_small(need);
  }
  return ok(simdutf_convert_valid_utf16le_to_utf8(U16(s), n, out));
}

static zuutf_result api_utf8_to_utf16le(const char *s, size_t n, uint16_t *out,
                                        size_t cap) {
  simdutf_result v = simdutf_validate_utf8_with_errors(s, n);
  if (v.error != SIMDUTF_ERROR_SUCCESS) {
    return from_simdutf(v);
  }
  size_t need = simdutf_utf16_length_from_utf8(s, n);
  if (need > cap) {
    return too_small(need);
  }
  return ok(simdutf_convert_valid_utf8_to_utf16le(s, n, (char16_t *) (void *) out));
}

static zuutf_result api_latin1_to_utf8(const char *s, size_t n, char *out,
                                       size_t cap) {
  size_t need = simdutf_utf8_length_from_latin1(s, n);
  if (need > cap) {
    return too_small(need);
  }
  return ok(simdutf_convert_latin1_to_utf8(s, n, out));
}

/* ZUUTF_BASE64_* flags to a simdutf_base64_options value. */
static simdutf_base64_options encode_options(unsigned flags) {
  int url = (flags & ZUUTF_BASE64_URL) != 0;
  int pad = (flags & ZUUTF_BASE64_NO_PAD) == 0;
  if (url) {
    return pad ? SIMDUTF_BASE64_URL_WITH_PADDING : SIMDUTF_BASE64_URL;
  }
  return pad ? SIMDUTF_BASE64_DEFAULT : SIMDUTF_BASE64_DEFAULT_NO_PADDING;
}

static size_t api_base64_encoded_length(size_t n, unsigned flags) {
  return simdutf_base64_length_from_binary(n, encode_options(flags));
}

static zuutf_result api_base64_encode(const unsigned char *s, size_t n,
                                      char *out, size_t cap, unsigned flags) {
  simdutf_base64_options opt = encode_options(flags);
  size_t need = simdutf_base64_length_from_binary(n, opt);
  if (need > cap) {
    return too_small(need);
  }
  return ok(simdutf_binary_to_base64((const char *) s, n, out, opt));
}

static size_t api_base64_decoded_max_length(const char *s, size_t n) {
  return simdutf_maximal_binary_length_from_base64(s, n);
}

static zuutf_result api_base64_decode(const char *s, size_t n, unsigned char *out,
                                      size_t cap, unsigned flags) {
  int options = (flags & ZUUTF_BASE64_EITHER) ? SIMDUTF_BASE64_DEFAULT_OR_URL
                : (flags & ZUUTF_BASE64_URL) ? SIMDUTF_BASE64_URL
                                             : SIMDUTF_BASE64_DEFAULT;
  size_t outlen = cap;
  simdutf_result r = zut_base64_decode_core(s, n, (char *) out, &outlen, options,
                                            (flags & ZUUTF_BASE64_STRICT) != 0);
  if (r.error == SIMDUTF_ERROR_OUTPUT_BUFFER_TOO_SMALL) {
    return too_small(simdutf_maximal_binary_length_from_base64(s, n));
  }
  if (r.error != SIMDUTF_ERROR_SUCCESS) {
    return from_simdutf(r);
  }
  return ok(outlen);
}

static const char *api_kernel(void) {
  return zut_active_kernel();
}

static const zuutf_api zuutf_api_table = {
  sizeof(zuutf_api),
  api_validate_utf8,
  api_validate_utf16le,
  api_validate_utf32,
  api_validate_ascii,
  api_count_utf8,
  api_utf8_length_from_utf16le,
  api_utf16_length_from_utf8,
  api_utf16le_to_utf8,
  api_utf8_to_utf16le,
  api_latin1_to_utf8,
  api_base64_encoded_length,
  api_base64_encode,
  api_base64_decoded_max_length,
  api_base64_decode,
  api_kernel,
};

static const zuutf_api *zuutf_api_v1(void) {
  return &zuutf_api_table;
}

void zut_register_api(void) {
  /* keyed on the package name; independent of symbol visibility (R3) */
  R_RegisterCCallable("zuutf", "zuutf_api_v1", (DL_FUNC) zuutf_api_v1);
}
