/* utf_length_as(): the bytes a conversion of each valid element will
 * produce, from simdutf's *_length_from_* functions where the C API has
 * them and from the code-point count where it does not. */
#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>
#include <stdint.h>

#include "simdutf_c.h"
#include "zut_check.h"
#include "zut_input.h"
#include "zut_r.h"

static size_t utf16_units_from_utf32(const uint32_t *s, size_t n) {
  size_t k = n;
  for (size_t i = 0; i < n; i++) {
    k += s[i] > 0xFFFF;
  }
  return k;
}

static int is_utf16(zut_enc e) { return e == ZUT_UTF16LE || e == ZUT_UTF16BE; }
static int is_utf32(zut_enc e) { return e == ZUT_UTF32LE || e == ZUT_UTF32BE; }

static double length_as(zut_scratch *s, zut_enc from, zut_enc to,
                        const char *p, size_t units) {
  if (to == ZUT_LATIN1 || is_utf32(to)) {
    size_t cp = zut_code_points(s, from, p, units);
    return (double) cp * (to == ZUT_LATIN1 ? 1.0 : 4.0);
  }
  if (to == ZUT_UTF8) {
    switch (from) {
    case ZUT_UTF8:
    case ZUT_ASCII:
      return (double) units;
    case ZUT_LATIN1:
      return (double) simdutf_utf8_length_from_latin1(p, units);
    case ZUT_UTF16LE:
      return (double) simdutf_utf8_length_from_utf16le(zut_as_utf16(s, p, units), units);
    case ZUT_UTF16BE:
      return (double) simdutf_utf8_length_from_utf16be(zut_as_utf16(s, p, units), units);
    default:
      return (double) simdutf_utf8_length_from_utf32(zut_as_utf32(s, from, p, units), units);
    }
  }
  /* to UTF-16, either order: two bytes per code unit */
  switch (from) {
  case ZUT_UTF8:
  case ZUT_ASCII:
    return 2.0 * (double) simdutf_utf16_length_from_utf8(p, units);
  case ZUT_LATIN1:
    return 2.0 * (double) units;
  default:
    if (is_utf16(from)) {
      return 2.0 * (double) units;
    }
    return 2.0 * (double) utf16_units_from_utf32(zut_as_utf32(s, from, p, units), units);
  }
}

SEXP zut_length_as(SEXP x, SEXP from, SEXP to) {
  zut_enc enc = (zut_enc) Rf_asInteger(from);
  zut_enc target = (zut_enc) Rf_asInteger(to);
  R_xlen_t len = zut_length(x);

  zut_scratch scratch;
  scratch.vec = PROTECT(zut_scratch_alloc(zut_max_bytes(x)));

  SEXP out = PROTECT(Rf_allocVector(REALSXP, len));
  double *dbl = REAL(out);
  for (R_xlen_t i = 0; i < len; i++) {
    if (i % ZUT_INTERRUPT_EVERY == ZUT_INTERRUPT_EVERY - 1) {
      R_CheckUserInterrupt();
    }
    const char *p;
    size_t n, units = 0, err = 0;
    if (!zut_element(x, i, &p, &n)) {
      dbl[i] = NA_REAL;
      continue;
    }
    zut_enc e = zut_strip_bom(enc, &p, &n);
    if (!zut_check(&scratch, e, p, n, &units, &err)) {
      dbl[i] = NA_REAL;
      continue;
    }
    dbl[i] = length_as(&scratch, e, target, p, units);
  }

  UNPROTECT(2);
  return out;
}
