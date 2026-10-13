/* utf_valid(), utf_error_at(), utf_is_ascii() and utf_count(): one pass per
 * element over simdutf's validate_*_with_errors and count_* functions. */
#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>
#include <stdint.h>

#include "simdutf_c.h"
#include "zut_check.h"
#include "zut_input.h"
#include "zut_r.h"

int zut_check(zut_scratch *s, zut_enc enc, const char *p, size_t n,
              size_t *units, size_t *err) {
  size_t size = zut_unit_size(enc);
  size_t whole = n / size;
  simdutf_result r = {SIMDUTF_ERROR_SUCCESS, 0};

  switch (enc) {
  case ZUT_UTF8:
    r = simdutf_validate_utf8_with_errors(p, n);
    break;
  case ZUT_ASCII:
    r = simdutf_validate_ascii_with_errors(p, n);
    break;
  case ZUT_LATIN1:
    break;
  case ZUT_UTF16LE:
    r = simdutf_validate_utf16le_with_errors(zut_as_utf16(s, p, whole), whole);
    break;
  case ZUT_UTF16BE:
    r = simdutf_validate_utf16be_with_errors(zut_as_utf16(s, p, whole), whole);
    break;
  case ZUT_UTF32LE:
  case ZUT_UTF32BE:
    r = simdutf_validate_utf32_with_errors(zut_as_utf32(s, enc, p, whole), whole);
    break;
  default:
    Rf_error("zuutf internal: unresolved encoding %d", (int) enc);
  }

  if (r.error != SIMDUTF_ERROR_SUCCESS) {
    *err = r.count;
    return 0;
  }
  if (whole * size != n) {
    *err = whole;
    return 0;
  }
  *units = whole;
  return 1;
}

size_t zut_code_points(zut_scratch *s, zut_enc enc, const char *p, size_t units) {
  switch (enc) {
  case ZUT_UTF8:
    return simdutf_count_utf8(p, units);
  case ZUT_UTF16LE:
    return simdutf_count_utf16le(zut_as_utf16(s, p, units), units);
  case ZUT_UTF16BE:
    return simdutf_count_utf16be(zut_as_utf16(s, p, units), units);
  default: /* UTF-32, Latin-1, ASCII: one unit per code point */
    return units;
  }
}

/* what: 0 valid (logical), 1 offset of the first error (1-based), 2 code
 * points. Offsets and counts are doubles; R converts them to integer when
 * they fit. */
SEXP zut_validate(SEXP x, SEXP encoding, SEXP what) {
  zut_enc enc = (zut_enc) Rf_asInteger(encoding);
  int mode = Rf_asInteger(what);
  R_xlen_t len = zut_length(x);

  zut_scratch scratch;
  scratch.vec = PROTECT(zut_scratch_alloc(zut_max_bytes(x)));

  SEXP out = PROTECT(Rf_allocVector(mode == 0 ? LGLSXP : REALSXP, len));
  int *lgl = mode == 0 ? LOGICAL(out) : NULL;
  double *dbl = mode == 0 ? NULL : REAL(out);

  for (R_xlen_t i = 0; i < len; i++) {
    if (i % ZUT_INTERRUPT_EVERY == ZUT_INTERRUPT_EVERY - 1) {
      R_CheckUserInterrupt();
    }
    const char *p;
    size_t n, units = 0, err = 0;
    if (!zut_element(x, i, &p, &n)) {
      if (lgl) lgl[i] = NA_LOGICAL;
      else dbl[i] = NA_REAL;
      continue;
    }
    zut_enc e = zut_strip_bom(enc, &p, &n);
    int ok = zut_check(&scratch, e, p, n, &units, &err);
    switch (mode) {
    case 0:
      lgl[i] = ok;
      break;
    case 1:
      dbl[i] = ok ? NA_REAL : (double) err + 1.0;
      break;
    default:
      dbl[i] = ok ? (double) zut_code_points(&scratch, e, p, units) : NA_REAL;
      break;
    }
  }

  UNPROTECT(2);
  return out;
}
