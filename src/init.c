#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>
#include <R_ext/Visibility.h>

#include "zut_api.h"
#include "zut_r.h"

static const R_CallMethodDef call_methods[] = {
  {"zut_info", (DL_FUNC) &zut_info, 0},
  {"zut_force_kernel", (DL_FUNC) &zut_force_kernel_r, 1},
  {"zut_kernel_ok", (DL_FUNC) &zut_kernel_ok, 0},
  {"zut_validate", (DL_FUNC) &zut_validate, 3},
  {"zut_length_as", (DL_FUNC) &zut_length_as, 3},
  {"zut_convert", (DL_FUNC) &zut_convert, 6},
  {"zut_detect", (DL_FUNC) &zut_detect, 1},
  {"zut_base64_encode", (DL_FUNC) &zut_base64_encode, 3},
  {"zut_base64_decode", (DL_FUNC) &zut_base64_decode, 3},
  {NULL, NULL, 0}
};

void attribute_visible R_init_zuutf(DllInfo *dll) {
  R_registerRoutines(dll, NULL, call_methods, NULL, NULL);
  R_useDynamicSymbols(dll, FALSE);
  R_forceSymbols(dll, TRUE);
  zut_register_api();
}
