/* The .Call entry points, registered in init.c. */
#ifndef ZUT_R_H
#define ZUT_R_H

#include <Rinternals.h>

SEXP zut_info(void);
SEXP zut_probe(SEXP x);
SEXP zut_force_kernel_r(SEXP name);
SEXP zut_kernel_ok(void);
SEXP zut_validate(SEXP x, SEXP encoding, SEXP what);
SEXP zut_length_as(SEXP x, SEXP from, SEXP to);
SEXP zut_convert(SEXP x, SEXP from, SEXP to, SEXP policy, SEXP mode,
                 SEXP simdutf_replacement);
SEXP zut_detect(SEXP x);
SEXP zut_base64_encode(SEXP x, SEXP options, SEXP line_length);
SEXP zut_base64_decode(SEXP x, SEXP options, SEXP strict);

#endif
