/* Validation of one element (design §6). */
#ifndef ZUT_CHECK_H
#define ZUT_CHECK_H

#include "zut_input.h"

/* Validate n bytes at p in the concrete encoding enc (BOM already
 * stripped). Returns 1 when valid. Otherwise returns 0 and sets *err to the
 * 0-based offset of the first error in code units of enc; a trailing
 * partial code unit (an odd byte in UTF-16, one to three in UTF-32) is an
 * error at the offset of that unit. On success *units is the number of
 * whole code units. */
int zut_check(zut_scratch *s, zut_enc enc, const char *p, size_t n,
              size_t *units, size_t *err);

/* Code points in a valid element (zut_check returned 1). */
size_t zut_code_points(zut_scratch *s, zut_enc enc, const char *p, size_t units);

#endif
