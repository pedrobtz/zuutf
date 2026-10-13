/* The Base64 decoder shared by base64_decode() and the C table. */
#ifndef ZUT_BASE64_H
#define ZUT_BASE64_H

#include <stddef.h>

#include "simdutf_c.h"

/* Decode n characters at p into out, which holds *outlen bytes; *outlen
 * becomes the bytes written. options is a simdutf_base64_options value.
 * strict: RFC 4648 read strictly, whitespace refused. On a remainder or
 * extra-bits error, count is the offset of the last character carrying
 * data; on an invalid character, its offset. */
simdutf_result zut_base64_decode_core(const char *p, size_t n, char *out,
                                      size_t *outlen, int options, int strict);

#endif
