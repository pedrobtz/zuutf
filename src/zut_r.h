/* The .Call entry points, registered in init.c. */
#ifndef ZUT_R_H
#define ZUT_R_H

#include <Rinternals.h>

SEXP zut_info(void);
SEXP zut_probe(SEXP x);
SEXP zut_force_kernel_r(SEXP name);

#endif
