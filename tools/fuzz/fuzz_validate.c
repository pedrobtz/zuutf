/* utf_valid(), utf_error_at(), utf_count() and utf_length_as() on any bytes
 * in any encoding: the three answers agree, the bytes before a reported
 * error are valid, and every length of a valid input is defined. */
#include "fuzz.h"
#include "zut_input.h"

static void run(void *data) {
  zut_fuzz_in *in = (zut_fuzz_in *) data;
  int enc = 1 + zut_fuzz_u8(in) % 9;
  SEXP x = PROTECT(zut_fuzz_rest(in));
  SEXP e = PROTECT(Rf_ScalarInteger(enc));
  SEXP m0 = PROTECT(Rf_ScalarInteger(0)), m1 = PROTECT(Rf_ScalarInteger(1)),
       m2 = PROTECT(Rf_ScalarInteger(2));
  SEXP ok = PROTECT(zut_validate(x, e, m0));
  SEXP at = PROTECT(zut_validate(x, e, m1));
  SEXP cnt = PROTECT(zut_validate(x, e, m2));
  int valid = LOGICAL(ok)[0];
  FUZZ_CHECK(valid == ISNAN(REAL(at)[0]));
  FUZZ_CHECK(valid == !ISNAN(REAL(cnt)[0]));

  /* the BOM and the byte order the element resolves to */
  const char *p = (const char *) RAW(x);
  size_t n = (size_t) XLENGTH(x);
  zut_enc concrete = zut_strip_bom((zut_enc) enc, &p, &n);
  size_t bom = (size_t) XLENGTH(x) - n, unit = zut_unit_size(concrete);

  if (!valid) {
    /* everything before the error is valid in the resolved encoding */
    size_t before = (size_t) REAL(at)[0] - 1;
    FUZZ_CHECK(before * unit <= n);
    SEXP prefix = PROTECT(Rf_allocVector(RAWSXP, (R_xlen_t) (before * unit)));
    if (before) memcpy(RAW(prefix), p, before * unit);
    SEXP ce = PROTECT(Rf_ScalarInteger((int) concrete));
    FUZZ_CHECK(LOGICAL(zut_validate(prefix, ce, m0))[0]);
    UNPROTECT(2);
  } else if (enc != ZUT_ASCII) {
    for (int to = 1; to <= 6; to++) {
      SEXP t = PROTECT(Rf_ScalarInteger(to));
      SEXP len = PROTECT(zut_length_as(x, e, t));
      FUZZ_CHECK(!ISNAN(REAL(len)[0]));
      if (to == ZUT_UTF32LE) FUZZ_CHECK(REAL(len)[0] == 4 * REAL(cnt)[0]);
      UNPROTECT(2);
    }
    (void) bom;
  }
  if (valid && n > 0) FUZZ_ACCEPTED();
  UNPROTECT(8);
}

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  zut_fuzz_in in = {data, size, 0};
  zut_fuzz_run(run, &in);
  return 0;
}
