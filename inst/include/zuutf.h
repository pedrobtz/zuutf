/* zuutf.h -- zuutf's registered C table (design §7).
 *
 * A package that wants simdutf's validation, transcoding and Base64 in its
 * own C code, without vendoring simdutf, declares in DESCRIPTION
 *
 *   Imports: zuutf
 *   LinkingTo: zuutf
 *
 * and in NAMESPACE
 *
 *   importFrom(zuutf, zuutf_info)
 *
 * because R_GetCCallable() resolves nothing until zuutf's namespace is
 * loaded. In exactly one of its C files, after <R.h> and
 * <R_ext/Rdynload.h>:
 *
 *   #define ZUUTF_DEFINE_API_GET
 *   #include <zuutf.h>
 *
 * which defines a static zuutf_api_get(). Every other file includes
 * <zuutf.h> alone for the types. vignette("linking") walks through it.
 *
 * This header includes <stddef.h> and <stdint.h> only: no simdutf type and
 * no R header. UTF-16 and UTF-32 are uint16_t and uint32_t in native byte
 * order, little-endian on every platform R supports today.
 */
#ifndef ZUUTF_H
#define ZUUTF_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Error codes, mirroring simdutf's simdutf_error_code. src/zut_impl.cpp
 * checks with static_assert that the values agree. */
#define ZUUTF_ERR_SUCCESS 0
#define ZUUTF_ERR_HEADER_BITS 1               /* UTF-8: a byte no sequence starts with */
#define ZUUTF_ERR_TOO_SHORT 2                 /* UTF-8: a sequence cut short */
#define ZUUTF_ERR_TOO_LONG 3                  /* UTF-8: a continuation byte too many */
#define ZUUTF_ERR_OVERLONG 4                  /* UTF-8: an overlong form */
#define ZUUTF_ERR_TOO_LARGE 5                 /* above U+10FFFF, or above U+00FF for Latin-1 */
#define ZUUTF_ERR_SURROGATE 6                 /* an encoded or unpaired surrogate */
#define ZUUTF_ERR_INVALID_BASE64_CHARACTER 7  /* also whitespace in strict mode */
#define ZUUTF_ERR_BASE64_INPUT_REMAINDER 8    /* one character left over */
#define ZUUTF_ERR_BASE64_EXTRA_BITS 9         /* strict mode: non-zero unused bits */
#define ZUUTF_ERR_OUTPUT_BUFFER_TOO_SMALL 10
#define ZUUTF_ERR_OTHER 11

/* error is ZUUTF_ERR_SUCCESS or another ZUUTF_ERR_* code. count is, on
 * success, the units written (validation: the units read); on an input
 * error, the 0-based offset of the error in input units; on
 * ZUUTF_ERR_OUTPUT_BUFFER_TOO_SMALL, the capacity that would have been
 * enough. */
typedef struct {
  int error;
  size_t count;
} zuutf_result;

/* Base64 flags, or-ed together. */
#define ZUUTF_BASE64_URL 1u     /* the "-_" alphabet */
#define ZUUTF_BASE64_NO_PAD 2u  /* encode: write no "=" */
#define ZUUTF_BASE64_STRICT 4u  /* decode: RFC 4648 strictly; forgiving otherwise */
#define ZUUTF_BASE64_EITHER 8u  /* decode: accept both alphabets */

/* ---- registered function table ------------------------------------------
 *
 *   * struct_size versions THIS TABLE. Members are appended, never
 *     reordered or removed, so a consumer built against an older header
 *     keeps working: check ZUUTF_API_HAS(api, member) before calling a
 *     member that a later zuutf added.
 *
 *   * The registered NAME versions every OTHER type here (zuutf_result): a
 *     change to it bumps the name to zuutf_api_v2, so a stale consumer fails
 *     loudly in R_GetCCallable() instead of misreading a result.
 *
 * Every member is a pure function of its arguments: none calls into R, so a
 * consumer may call them from any thread. Members that write take the
 * capacity of the output and never write past it. A member that converts
 * expects valid input to be converted and reports the first error
 * otherwise; nothing is replaced.
 *
 * Name history:
 *   zuutf_api_v1 -- initial (zuutf 0.1.0).
 * ------------------------------------------------------------------------ */
typedef struct {
  uint32_t struct_size;

  /* validation; count is the units read on success */
  zuutf_result (*validate_utf8)(const char *s, size_t n);
  zuutf_result (*validate_utf16le)(const uint16_t *s, size_t n);
  zuutf_result (*validate_utf32)(const uint32_t *s, size_t n);
  int (*validate_ascii)(const char *s, size_t n); /* 1 when every byte < 0x80 */

  /* counts and lengths, for valid input */
  size_t (*count_utf8)(const char *s, size_t n);              /* code points */
  size_t (*utf8_length_from_utf16le)(const uint16_t *s, size_t n); /* bytes */
  size_t (*utf16_length_from_utf8)(const char *s, size_t n);  /* UTF-16 units */

  /* conversion; cap is in output units */
  zuutf_result (*utf16le_to_utf8)(const uint16_t *s, size_t n, char *out,
                                  size_t cap);
  zuutf_result (*utf8_to_utf16le)(const char *s, size_t n, uint16_t *out,
                                  size_t cap);
  zuutf_result (*latin1_to_utf8)(const char *s, size_t n, char *out, size_t cap);

  /* Base64, with ZUUTF_BASE64_* flags */
  size_t (*base64_encoded_length)(size_t n, unsigned flags);
  zuutf_result (*base64_encode)(const unsigned char *s, size_t n, char *out,
                                size_t cap, unsigned flags);
  size_t (*base64_decoded_max_length)(const char *s, size_t n);
  zuutf_result (*base64_decode)(const char *s, size_t n, unsigned char *out,
                                size_t cap, unsigned flags);

  /* the name of the active simdutf kernel, e.g. "haswell" */
  const char *(*kernel)(void);
} zuutf_api;

#define ZUUTF_API_HAS(api, member)                                            \
  ((api)->struct_size >= offsetof(zuutf_api, member) + sizeof((api)->member))

#ifdef ZUUTF_DEFINE_API_GET
/* R_GetCCallable() returns DL_FUNC; reading the getter back through a union
 * avoids the function-pointer cast clang flags under -Wcast-function-type.
 * R_GetCCallable() raises an R error itself when zuutf's namespace is not
 * loaded or the name is unknown. */
static const zuutf_api *zuutf_api_get(void) {
  static const zuutf_api *api = NULL;
  if (api == NULL) {
    union {
      DL_FUNC fn;
      const zuutf_api *(*get)(void);
    } resolve;
    resolve.fn = R_GetCCallable("zuutf", "zuutf_api_v1");
    if (resolve.fn != NULL) {
      api = resolve.get();
    }
  }
  return api;
}
#endif

#ifdef __cplusplus
}
#endif
#endif /* ZUUTF_H */
