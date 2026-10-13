/* utf_valid(), utf_error_at(), utf_is_ascii() and utf_count(): one view
 * per element over simdutf's validate_*_with_errors and count_* functions. */
#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>

#include "zut_input.h"
#include "zut_r.h"
#include "zut_view.h"

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
    size_t n, err = 0;
    if (!zut_element(x, i, &p, &n)) {
      if (lgl) lgl[i] = NA_LOGICAL;
      else dbl[i] = NA_REAL;
      continue;
    }
    zut_view v;
    zut_view_make(&v, &scratch, zut_strip_bom(enc, &p, &n), p, n);
    int ok = zut_view_validate(&v, 0, &err);
    if (ok && v.partial) {
      ok = 0;
      err = v.units; /* the trailing partial unit */
    }
    switch (mode) {
    case 0:
      lgl[i] = ok;
      break;
    case 1:
      dbl[i] = ok ? NA_REAL : (double) err + 1.0;
      break;
    default:
      dbl[i] = ok ? (double) zut_view_code_points(&v, 0, v.units) : NA_REAL;
      break;
    }
  }

  UNPROTECT(2);
  return out;
}
