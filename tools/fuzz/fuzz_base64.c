/* base64_decode() and base64_encode() on any bytes: what decodes re-encodes
 * to text that decodes strictly to the same bytes, and any bytes survive an
 * encode and a forgiving decode under every alphabet, padding and line
 * length. Strict decoding with pad = FALSE never accepts '=', and reads back
 * exactly what an unpadded single-line encoding wrote. */
#include "fuzz.h"

static void run(void *data) {
  zut_fuzz_in *in = (zut_fuzz_in *) data;
  static const int decode_opts[] = {0, 1, 8};   /* default, URL, either */
  int dopt = decode_opts[zut_fuzz_u8(in) % 3];
  int mode = zut_fuzz_u8(in);
  int strict = mode & 1;
  int pad = !(mode & 2);                        /* only read when strict */
  int eopt = zut_fuzz_u8(in) % 4;               /* simdutf_base64_options 0-3 */
  int lines = zut_fuzz_u8(in) % 80;
  SEXP x = PROTECT(zut_fuzz_rest(in));

  SEXP d = PROTECT(Rf_ScalarInteger(dopt)), s = PROTECT(Rf_ScalarLogical(strict));
  SEXP pd = PROTECT(Rf_ScalarLogical(pad)), padyes = PROTECT(Rf_ScalarLogical(1));
  SEXP res = PROTECT(zut_base64_decode(x, d, s, pd));
  double *st = REAL(VECTOR_ELT(res, 1));
  if (st[0] == 0) {
    SEXP bytes = VECTOR_ELT(res, 0);
    if (strict && !pad) {
      /* accepted unpadded text has no '=' anywhere */
      FUZZ_CHECK(memchr(RAW(x), '=', (size_t) XLENGTH(x)) == NULL);
    }
    /* canonical, padded text in the alphabet decoded */
    SEXP padded = PROTECT(Rf_ScalarInteger(dopt == 1 ? 3 : 0));
    SEXP none = PROTECT(Rf_ScalarReal(0));
    SEXP enc = PROTECT(zut_base64_encode(bytes, padded, none));
    FUZZ_CHECK(REAL(VECTOR_ELT(enc, 1))[0] == 0);
    SEXP yes = PROTECT(Rf_ScalarLogical(1));
    SEXP again = PROTECT(zut_base64_decode(VECTOR_ELT(enc, 0), d, yes, padyes));
    FUZZ_CHECK(REAL(VECTOR_ELT(again, 1))[0] == 0);
    SEXP b2 = VECTOR_ELT(again, 0);
    FUZZ_CHECK(XLENGTH(b2) == XLENGTH(bytes) &&
               (XLENGTH(b2) == 0 || memcmp(RAW(b2), RAW(bytes), (size_t) XLENGTH(b2)) == 0));
    if (XLENGTH(bytes) > 0) FUZZ_ACCEPTED();
    UNPROTECT(5);
  } else {
    FUZZ_CHECK(st[1] >= 1 && st[1] <= (double) XLENGTH(x) + 1);
  }

  /* any bytes round-trip */
  SEXP eo = PROTECT(Rf_ScalarInteger(eopt)), ll = PROTECT(Rf_ScalarReal(lines));
  SEXP enc = PROTECT(zut_base64_encode(x, eo, ll));
  FUZZ_CHECK(REAL(VECTOR_ELT(enc, 1))[0] == 0);
  SEXP alpha = PROTECT(Rf_ScalarInteger(eopt & 1 ? 1 : 0)), no = PROTECT(Rf_ScalarLogical(0));
  SEXP back = PROTECT(zut_base64_decode(VECTOR_ELT(enc, 0), alpha, no, padyes));
  FUZZ_CHECK(REAL(VECTOR_ELT(back, 1))[0] == 0);
  SEXP b = VECTOR_ELT(back, 0);
  FUZZ_CHECK(XLENGTH(b) == XLENGTH(x) &&
             (XLENGTH(x) == 0 || memcmp(RAW(b), RAW(x), (size_t) XLENGTH(x)) == 0));
  /* an unpadded encoding on one line reads back strictly with pad = FALSE */
  if ((eopt == 1 || eopt == 2) && lines < 4) {
    SEXP yes2 = PROTECT(Rf_ScalarLogical(1)), nopad = PROTECT(Rf_ScalarLogical(0));
    SEXP strict_back = PROTECT(zut_base64_decode(VECTOR_ELT(enc, 0), alpha, yes2, nopad));
    FUZZ_CHECK(REAL(VECTOR_ELT(strict_back, 1))[0] == 0);
    SEXP sb = VECTOR_ELT(strict_back, 0);
    FUZZ_CHECK(XLENGTH(sb) == XLENGTH(x) &&
               (XLENGTH(x) == 0 || memcmp(RAW(sb), RAW(x), (size_t) XLENGTH(x)) == 0));
    UNPROTECT(3);
  }
  UNPROTECT(12);
}

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  zut_fuzz_in in = {data, size, 0};
  zut_fuzz_run(run, &in);
  return 0;
}
