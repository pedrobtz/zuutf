/* utf_length_as(): the bytes a conversion of each valid element will
 * produce, from simdutf's *_length_from_* functions where the C API has
 * them and from the code-point count where it does not. */
#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>

#include "zut_input.h"
#include "zut_r.h"
#include "zut_view.h"

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
    size_t n, err = 0;
    if (!zut_element(x, i, &p, &n)) {
      dbl[i] = NA_REAL;
      continue;
    }
    zut_view v;
    /* zut_strip_bom() advances p and n, so it runs first: the order in
     * which C evaluates arguments is unspecified, and GCC reads p and n
     * before the call where clang reads them after it */
    zut_enc e = zut_strip_bom(enc, &p, &n);
    zut_view_make(&v, &scratch, e, p, n);
    if (!zut_view_validate(&v, 0, &err) || v.partial) {
      dbl[i] = NA_REAL;
      continue;
    }
    dbl[i] = (double) zut_view_length(&v, 0, v.units, target);
  }

  UNPROTECT(2);
  return out;
}
