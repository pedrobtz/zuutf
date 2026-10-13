/* base64_decode() and base64_encode() on any bytes: what decodes re-encodes
 * to text that decodes strictly to the same bytes, and any bytes survive an
 * encode and a forgiving decode under every alphabet, padding and line
 * length. */
#include "fuzz.h"

static void run(void *data) {
  zut_fuzz_in *in = (zut_fuzz_in *) data;
  static const int decode_opts[] = {0, 1, 8};   /* default, URL, either */
  int dopt = decode_opts[zut_fuzz_u8(in) % 3];
  int strict = zut_fuzz_u8(in) & 1;
  int eopt = zut_fuzz_u8(in) % 4;               /* simdutf_base64_options 0-3 */
  int lines = zut_fuzz_u8(in) % 80;
  SEXP x = PROTECT(zut_fuzz_rest(in));

  SEXP d = PROTECT(Rf_ScalarInteger(dopt)), s = PROTECT(Rf_ScalarLogical(strict));
  SEXP res = PROTECT(zut_base64_decode(x, d, s));
  double *st = REAL(VECTOR_ELT(res, 1));
  if (st[0] == 0) {
    SEXP bytes = VECTOR_ELT(res, 0);
    /* canonical, padded text in the alphabet decoded */
    SEXP padded = PROTECT(Rf_ScalarInteger(dopt == 1 ? 3 : 0));
    SEXP none = PROTECT(Rf_ScalarReal(0));
    SEXP enc = PROTECT(zut_base64_encode(bytes, padded, none));
    FUZZ_CHECK(REAL(VECTOR_ELT(enc, 1))[0] == 0);
    SEXP yes = PROTECT(Rf_ScalarLogical(1));
    SEXP again = PROTECT(zut_base64_decode(VECTOR_ELT(enc, 0), d, yes));
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
  SEXP back = PROTECT(zut_base64_decode(VECTOR_ELT(enc, 0), alpha, no));
  FUZZ_CHECK(REAL(VECTOR_ELT(back, 1))[0] == 0);
  SEXP b = VECTOR_ELT(back, 0);
  FUZZ_CHECK(XLENGTH(b) == XLENGTH(x) &&
             (XLENGTH(x) == 0 || memcmp(RAW(b), RAW(x), (size_t) XLENGTH(x)) == 0));
  UNPROTECT(10);
}

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  zut_fuzz_in in = {data, size, 0};
  zut_fuzz_run(run, &in);
  return 0;
}
