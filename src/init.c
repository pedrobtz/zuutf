#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>
#include <R_ext/Visibility.h>

#include "zut_r.h"

static const R_CallMethodDef call_methods[] = {
  {"zut_info", (DL_FUNC) &zut_info, 0},
  {"zut_probe", (DL_FUNC) &zut_probe, 1},
  {"zut_force_kernel", (DL_FUNC) &zut_force_kernel_r, 1},
  {NULL, NULL, 0}
};

void attribute_visible R_init_zuutf(DllInfo *dll) {
  R_registerRoutines(dll, NULL, call_methods, NULL, NULL);
  R_useDynamicSymbols(dll, FALSE);
  R_forceSymbols(dll, TRUE);
}
