/* .Call glue for zuutf_info(), the internal probe and kernel forcing. */
#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>

#include "simdutf_c.h"
#include "zut_impl.h"
#include "zut_r.h"

SEXP zut_info(void) {
  int n = zut_kernel_count();
  SEXP names = PROTECT(Rf_allocVector(STRSXP, n));
  SEXP descriptions = PROTECT(Rf_allocVector(STRSXP, n));
  SEXP supported = PROTECT(Rf_allocVector(LGLSXP, n));
  for (int i = 0; i < n; i++) {
    SET_STRING_ELT(names, i, Rf_mkChar(zut_kernel_name(i)));
    SET_STRING_ELT(descriptions, i, Rf_mkChar(zut_kernel_description(i)));
    LOGICAL(supported)[i] = zut_kernel_supported(i);
  }

  SEXP out = PROTECT(Rf_allocVector(VECSXP, 5));
  SET_VECTOR_ELT(out, 0, Rf_mkString(zut_simdutf_version()));
  SET_VECTOR_ELT(out, 1, Rf_mkString(zut_active_kernel()));
  SET_VECTOR_ELT(out, 2, names);
  SET_VECTOR_ELT(out, 3, descriptions);
  SET_VECTOR_ELT(out, 4, supported);
  SEXP nms = PROTECT(Rf_allocVector(STRSXP, 5));
  SET_STRING_ELT(nms, 0, Rf_mkChar("simdutf"));
  SET_STRING_ELT(nms, 1, Rf_mkChar("kernel"));
  SET_STRING_ELT(nms, 2, Rf_mkChar("name"));
  SET_STRING_ELT(nms, 3, Rf_mkChar("description"));
  SET_STRING_ELT(nms, 4, Rf_mkChar("supported"));
  Rf_setAttrib(out, R_NamesSymbol, nms);
  UNPROTECT(5);
  return out;
}

SEXP zut_probe(SEXP x) {
  if (TYPEOF(x) != RAWSXP) {
    Rf_error("`x` must be a raw vector");
  }
  bool ok = simdutf_validate_utf8((const char *) RAW(x), (size_t) XLENGTH(x));
  return Rf_ScalarLogical(ok ? 1 : 0);
}

SEXP zut_force_kernel_r(SEXP name) {
  if (TYPEOF(name) != STRSXP || XLENGTH(name) != 1 ||
      STRING_ELT(name, 0) == NA_STRING) {
    Rf_error("`name` must be a single string");
  }
  return Rf_ScalarLogical(zut_force_kernel(CHAR(STRING_ELT(name, 0))));
}
