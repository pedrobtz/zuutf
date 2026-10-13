#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>
#include <string.h>

#include "zut_input.h"

R_xlen_t zut_length(SEXP x) {
  return TYPEOF(x) == RAWSXP ? 1 : XLENGTH(x);
}

int zut_element(SEXP x, R_xlen_t i, const char **p, size_t *n) {
  switch (TYPEOF(x)) {
  case STRSXP: {
    SEXP s = STRING_ELT(x, i);
    if (s == NA_STRING) {
      return 0;
    }
    *p = CHAR(s);
    *n = (size_t) LENGTH(s);
    return 1;
  }
  case RAWSXP:
    *p = (const char *) RAW(x);
    *n = (size_t) XLENGTH(x);
    return 1;
  case VECSXP: {
    SEXP e = VECTOR_ELT(x, i);
    if (e == R_NilValue) {
      return 0;
    }
    *p = (const char *) RAW(e);
    *n = (size_t) XLENGTH(e);
    return 1;
  }
  default:
    Rf_error("zuutf internal: unexpected input type"); /* R checks shapes */
  }
  return 0;
}

size_t zut_max_bytes(SEXP x) {
  size_t max = 0;
  R_xlen_t len = zut_length(x);
  for (R_xlen_t i = 0; i < len; i++) {
    const char *p;
    size_t n;
    if (zut_element(x, i, &p, &n) && n > max) {
      max = n;
    }
  }
  return max;
}

static int has_prefix(const char *p, size_t n, const char *bom, size_t k) {
  return n >= k && memcmp(p, bom, k) == 0;
}

zut_enc zut_strip_bom(zut_enc enc, const char **p, size_t *n) {
  static const char utf8[] = "\xEF\xBB\xBF";
  static const char le16[] = "\xFF\xFE";
  static const char be16[] = "\xFE\xFF";
  static const char le32[] = "\xFF\xFE\x00\x00";
  static const char be32[] = "\x00\x00\xFE\xFF";
  size_t skip = 0;
  zut_enc out = enc;

  switch (enc) {
  case ZUT_UTF8:
    skip = has_prefix(*p, *n, utf8, 3) ? 3 : 0;
    break;
  case ZUT_UTF16LE:
    skip = has_prefix(*p, *n, le16, 2) ? 2 : 0;
    break;
  case ZUT_UTF16BE:
    skip = has_prefix(*p, *n, be16, 2) ? 2 : 0;
    break;
  case ZUT_UTF32LE:
    skip = has_prefix(*p, *n, le32, 4) ? 4 : 0;
    break;
  case ZUT_UTF32BE:
    skip = has_prefix(*p, *n, be32, 4) ? 4 : 0;
    break;
  case ZUT_UTF16:
    if (has_prefix(*p, *n, le16, 2)) {
      out = ZUT_UTF16LE;
      skip = 2;
    } else {
      out = ZUT_UTF16BE;
      skip = has_prefix(*p, *n, be16, 2) ? 2 : 0;
    }
    break;
  case ZUT_UTF32:
    if (has_prefix(*p, *n, le32, 4)) {
      out = ZUT_UTF32LE;
      skip = 4;
    } else {
      out = ZUT_UTF32BE;
      skip = has_prefix(*p, *n, be32, 4) ? 4 : 0;
    }
    break;
  default:
    break;
  }
  *p += skip;
  *n -= skip;
  return out;
}

size_t zut_unit_size(zut_enc enc) {
  switch (enc) {
  case ZUT_UTF16LE:
  case ZUT_UTF16BE:
    return 2;
  case ZUT_UTF32LE:
  case ZUT_UTF32BE:
    return 4;
  default:
    return 1;
  }
}

SEXP zut_scratch_alloc(size_t max_bytes) {
  return Rf_allocVector(RAWSXP, (R_xlen_t) (max_bytes ? max_bytes : 1));
}

static int little_endian(void) {
  const uint16_t one = 1;
  return *(const unsigned char *) &one == 1;
}

const uint16_t *zut_as_utf16(zut_scratch *s, const char *p, size_t units) {
  if (((uintptr_t) p % sizeof(uint16_t)) == 0) {
    return (const uint16_t *) (const void *) p;
  }
  memcpy(RAW(s->vec), p, units * 2);
  return (const uint16_t *) (void *) RAW(s->vec);
}

const uint32_t *zut_as_utf32(zut_scratch *s, zut_enc enc, const char *p,
                             size_t units) {
  int native = (enc == ZUT_UTF32LE) == little_endian();
  if (native && ((uintptr_t) p % sizeof(uint32_t)) == 0) {
    return (const uint32_t *) (const void *) p;
  }
  unsigned char *out = RAW(s->vec);
  if (native) {
    memcpy(out, p, units * 4);
  } else {
    const unsigned char *in = (const unsigned char *) p;
    for (size_t i = 0; i < units; i++) {
      out[4 * i] = in[4 * i + 3];
      out[4 * i + 1] = in[4 * i + 2];
      out[4 * i + 2] = in[4 * i + 1];
      out[4 * i + 3] = in[4 * i];
    }
  }
  return (const uint32_t *) (void *) out;
}
