/* base64_encode() and base64_decode() over simdutf's Base64 (design §6,
 * D14). Forgiving decoding is simdutf's default with a loose last chunk;
 * strict decoding is a strict last chunk plus zuutf's own refusal of ASCII
 * whitespace, which simdutf skips in every mode. */
#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>
#include <limits.h>
#include <string.h>

#include "simdutf_c.h"
#include "zut_base64.h"
#include "zut_r.h"

/* Status kinds, as R/base64.R reads them. */
enum { ZUT_B64_OK = 0, ZUT_B64_INVALID = 1, ZUT_B64_TOO_LONG = 2, ZUT_B64_INTERNAL = 3 };

static void bytes_of(SEXP x, const char **p, size_t *n) {
  if (TYPEOF(x) == RAWSXP) {
    *p = (const char *) RAW(x);
    *n = (size_t) XLENGTH(x);
  } else {
    SEXP s = STRING_ELT(x, 0);
    *p = CHAR(s);
    *n = (size_t) LENGTH(s);
  }
}

static int is_ascii_space(unsigned char c) {
  return c == ' ' || c == '\t' || c == '\n' || c == '\f' || c == '\r';
}

/* The last character that carries data: not whitespace, not '='. */
static size_t last_significant(const char *p, size_t n) {
  while (n > 0 && (is_ascii_space((unsigned char) p[n - 1]) || p[n - 1] == '=')) {
    n--;
  }
  return n ? n - 1 : 0;
}

static SEXP result(SEXP value, int kind, size_t offset) {
  SEXP out = PROTECT(Rf_allocVector(VECSXP, 2));
  SEXP st = PROTECT(Rf_allocVector(REALSXP, 2));
  REAL(st)[0] = kind;
  REAL(st)[1] = (double) offset + 1.0;
  SET_VECTOR_ELT(out, 0, value);
  SET_VECTOR_ELT(out, 1, st);
  UNPROTECT(2);
  return out;
}

/* options: a simdutf_base64_options value; line_length 0 for none. */
SEXP zut_base64_encode(SEXP x, SEXP options, SEXP line_length) {
  const char *p;
  size_t n;
  bytes_of(x, &p, &n);
  simdutf_base64_options opt = (simdutf_base64_options) Rf_asInteger(options);
  /* R passes 0 or a whole number in [4, INT_MAX]; anything else is one line,
   * so a bad value cannot reach an out-of-range double to size_t cast */
  double d = Rf_asReal(line_length);
  size_t lines = d >= 4 && d <= INT_MAX ? (size_t) d : 0;

  size_t len = lines ? simdutf_base64_length_from_binary_with_lines(n, opt, lines)
                     : simdutf_base64_length_from_binary(n, opt);
  if (len > (size_t) INT_MAX) {
    return result(R_NilValue, ZUT_B64_TOO_LONG, 0);
  }
  SEXP buf = PROTECT(Rf_allocVector(RAWSXP, (R_xlen_t) (len ? len : 1)));
  size_t wrote = lines ? simdutf_binary_to_base64_with_lines(p, n, (char *) RAW(buf), lines, opt)
                       : simdutf_binary_to_base64(p, n, (char *) RAW(buf), opt);
  if (wrote != len) {
    UNPROTECT(1);
    return result(R_NilValue, ZUT_B64_INTERNAL, 0);
  }
  SEXP s = PROTECT(Rf_ScalarString(Rf_mkCharLenCE((const char *) RAW(buf), (int) wrote, CE_UTF8)));
  SEXP out = result(s, ZUT_B64_OK, 0);
  UNPROTECT(2);
  return out;
}

simdutf_result zut_base64_decode_core(const char *p, size_t n, char *out,
                                      size_t *outlen, int options, int strict) {
  simdutf_result r = {SIMDUTF_ERROR_SUCCESS, 0};
  if (strict) {
    for (size_t i = 0; i < n; i++) {
      if (is_ascii_space((unsigned char) p[i])) {
        r.error = SIMDUTF_ERROR_INVALID_BASE64_CHARACTER;
        r.count = i;
        return r;
      }
    }
  }
  r = simdutf_base64_to_binary_safe(
      p, n, out, outlen, (simdutf_base64_options) options,
      strict ? SIMDUTF_LAST_CHUNK_STRICT : SIMDUTF_LAST_CHUNK_LOOSE, false);
  if (r.error == SIMDUTF_ERROR_BASE64_INPUT_REMAINDER ||
      r.error == SIMDUTF_ERROR_BASE64_EXTRA_BITS) {
    /* the offending character is the last one that carries data */
    r.count = last_significant(p, n);
  }
  return r;
}

/* options: a simdutf_base64_options value; strict: RFC 4648 read strictly. */
SEXP zut_base64_decode(SEXP x, SEXP options, SEXP strict) {
  const char *p;
  size_t n;
  bytes_of(x, &p, &n);

  size_t cap = simdutf_maximal_binary_length_from_base64(p, n);
  SEXP buf = PROTECT(Rf_allocVector(RAWSXP, (R_xlen_t) (cap ? cap : 1)));
  size_t outlen = cap;
  simdutf_result r = zut_base64_decode_core(p, n, (char *) RAW(buf), &outlen,
                                            Rf_asInteger(options),
                                            Rf_asLogical(strict) == TRUE);
  SEXP out;
  switch (r.error) {
  case SIMDUTF_ERROR_SUCCESS: {
    SEXP v = PROTECT(Rf_allocVector(RAWSXP, (R_xlen_t) outlen));
    if (outlen) {
      memcpy(RAW(v), RAW(buf), outlen);
    }
    out = result(v, ZUT_B64_OK, 0);
    UNPROTECT(1);
    break;
  }
  case SIMDUTF_ERROR_INVALID_BASE64_CHARACTER:
  case SIMDUTF_ERROR_BASE64_INPUT_REMAINDER:
  case SIMDUTF_ERROR_BASE64_EXTRA_BITS:
    out = result(R_NilValue, ZUT_B64_INVALID, r.count);
    break;
  default:
    out = result(R_NilValue, ZUT_B64_INTERNAL, 0);
    break;
  }
  UNPROTECT(1);
  return out;
}
