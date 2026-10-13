/* utf_convert() and utf_decode() on any bytes, between any pair, under any
 * policy: a result is valid in its target, a string is UTF-8 without NUL,
 * a reported error is within the input, and a conversion that succeeded
 * under "error" converts back to the input. */
#include "fuzz.h"
#include "zut_input.h"

static const int targets[] = {ZUT_UTF8, ZUT_UTF16LE, ZUT_UTF16BE,
                              ZUT_UTF32LE, ZUT_UTF32BE, ZUT_LATIN1};

static void run(void *data) {
  zut_fuzz_in *in = (zut_fuzz_in *) data;
  int from = 1 + zut_fuzz_u8(in) % 10;
  if (from == ZUT_ASCII) from = ZUT_AUTO;
  int to = targets[zut_fuzz_u8(in) % 6];
  int policy = zut_fuzz_u8(in) % 3;
  int chr = zut_fuzz_u8(in) & 1;
  int simdutf = zut_fuzz_u8(in) & 1;
  if (chr) to = ZUT_UTF8;

  SEXP x = PROTECT(zut_fuzz_rest(in));
  SEXP f = PROTECT(Rf_ScalarInteger(from)), t = PROTECT(Rf_ScalarInteger(to));
  SEXP pol = PROTECT(Rf_ScalarInteger(policy)), mode = PROTECT(Rf_ScalarInteger(chr));
  SEXP rep = PROTECT(Rf_ScalarLogical(simdutf));
  SEXP res = PROTECT(zut_convert(x, f, t, pol, mode, rep));
  SEXP value = VECTOR_ELT(res, 0);
  double *st = REAL(VECTOR_ELT(res, 1));
  SEXP m0 = PROTECT(Rf_ScalarInteger(0));

  if (st[0] != 0) {
    FUZZ_CHECK(st[1] == 1);                                   /* the one element */
    FUZZ_CHECK(st[2] >= 1 && st[2] <= (double) XLENGTH(x) + 1);
    FUZZ_CHECK(!(policy == 1 && (st[0] == 1 || st[0] == 2)));  /* replace: never */
    UNPROTECT(8);
    return;
  }
  if (chr) {
    SEXP s = STRING_ELT(value, 0);
    if (s != NA_STRING) {
      SEXP u = PROTECT(Rf_ScalarString(s));
      SEXP e8 = PROTECT(Rf_ScalarInteger(ZUT_UTF8));
      FUZZ_CHECK(LOGICAL(zut_validate(u, e8, m0))[0]);
      FUZZ_CHECK(memchr(CHAR(s), 0, (size_t) LENGTH(s)) == NULL);
      UNPROTECT(2);
    }
  } else {
    SEXP out = VECTOR_ELT(value, 0);
    if (out != R_NilValue) {
      FUZZ_CHECK(LOGICAL(zut_validate(out, t, m0))[0]);
      /* a leading U+FEFF in the output reads back as a BOM and is dropped,
       * as the design says it must be, so the round trip skips it */
      const char *o = (const char *) RAW(out);
      size_t on = (size_t) XLENGTH(out);
      zut_strip_bom((zut_enc) to, &o, &on);
      int bom_out = on != (size_t) XLENGTH(out);
      if (policy == 0 && from <= ZUT_LATIN1 && !bom_out) {
        /* back again: the input without a BOM that matches from */
        const char *p = (const char *) RAW(x);
        size_t n = (size_t) XLENGTH(x);
        zut_strip_bom((zut_enc) from, &p, &n);
        SEXP back = PROTECT(zut_convert(out, t, f, pol, mode, rep));
        FUZZ_CHECK(REAL(VECTOR_ELT(back, 1))[0] == 0);
        SEXP b = VECTOR_ELT(VECTOR_ELT(back, 0), 0);
        FUZZ_CHECK((size_t) XLENGTH(b) == n && (n == 0 || memcmp(RAW(b), p, n) == 0));
        UNPROTECT(1);
      }
      if (XLENGTH(out) > 0) FUZZ_ACCEPTED();
    }
  }
  UNPROTECT(8);
}

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  zut_fuzz_in in = {data, size, 0};
  zut_fuzz_run(run, &in);
  return 0;
}
