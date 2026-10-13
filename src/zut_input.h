/* Input handling shared by the .Call entry points: element access over the
 * three input shapes, encoding codes, byte-order marks, and the scratch
 * buffer that aligns UTF-16 and UTF-32 input and swaps UTF-32 to native
 * order (design §4, §6, D13). */
#ifndef ZUT_INPUT_H
#define ZUT_INPUT_H

#include <stddef.h>
#include <stdint.h>
#include <Rinternals.h>

/* Encoding codes, as R/encoding.R numbers them. */
typedef enum {
  ZUT_UTF8 = 1,
  ZUT_UTF16LE = 2,
  ZUT_UTF16BE = 3,
  ZUT_UTF32LE = 4,
  ZUT_UTF32BE = 5,
  ZUT_LATIN1 = 6,
  ZUT_ASCII = 7,
  ZUT_UTF16 = 8, /* a BOM decides; big-endian without one */
  ZUT_UTF32 = 9,
  ZUT_AUTO = 10  /* conversion input only: utf_detect()'s first candidate */
} zut_enc;

/* Element i of a character vector, a raw vector (one element) or a list of
 * raw vectors. Returns 0 for an NA string or a NULL list element. */
int zut_element(SEXP x, R_xlen_t i, const char **p, size_t *n);

/* Number of elements of x in the sense of zut_element(). */
R_xlen_t zut_length(SEXP x);

/* Strip a leading byte-order mark that matches enc, and resolve "UTF-16"
 * and "UTF-32" to a concrete byte order. Returns the concrete encoding. */
zut_enc zut_strip_bom(zut_enc enc, const char **p, size_t *n);

/* Bytes per code unit of a concrete encoding. */
size_t zut_unit_size(zut_enc enc);

/* A scratch buffer owned by R, so an interrupt or error frees it. The
 * caller protects vec:
 *
 *   zut_scratch s;
 *   s.vec = PROTECT(zut_scratch_alloc(zut_max_bytes(x)));
 */
typedef struct {
  SEXP vec; /* a RAWSXP at least as long as the largest element */
} zut_scratch;

SEXP zut_scratch_alloc(size_t max_bytes);

/* p as UTF-16 code units, copied into the scratch if p is not aligned. */
const uint16_t *zut_as_utf16(zut_scratch *s, const char *p, size_t units);

/* p as native-order UTF-32 code units: swapped into the scratch when enc is
 * the non-native order, copied when p is not aligned. */
const uint32_t *zut_as_utf32(zut_scratch *s, zut_enc enc, const char *p,
                             size_t units);

/* Largest element in bytes, for sizing the scratch. */
size_t zut_max_bytes(SEXP x);

#define ZUT_INTERRUPT_EVERY 1024

#endif
