/* utf_convert(), utf_decode(), utf_encode() and utf_detect() (design §6,
 * D8). Each element is measured, then written into a buffer of exactly that
 * size: bulk runs go through simdutf, and zuutf's own code runs only at
 * errors, where it writes a replacement and skips the maximal subpart. */
#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>
#include <limits.h>
#include <stdint.h>
#include <string.h>

#include "simdutf_c.h"
#include "zut_input.h"
#include "zut_r.h"
#include "zut_view.h"

enum { ZUT_POLICY_ERROR = 0, ZUT_POLICY_REPLACE = 1, ZUT_POLICY_NA = 2 };

/* Status kinds, as R/convert.R reads them. */
enum {
  ZUT_OK = 0,
  ZUT_ILL_FORMED = 1,
  ZUT_UNREPRESENTABLE = 2,
  ZUT_NUL = 3,
  ZUT_TOO_LONG = 4
};

typedef struct {
  zut_enc to;
  int policy;
  int simdutf_replacement; /* use simdutf's UTF-16 -> UTF-8 replacement */
} zut_conv;

static int is_utf16(zut_enc e) { return e == ZUT_UTF16LE || e == ZUT_UTF16BE; }

static size_t emit(const zut_view *v, size_t pos, size_t cnt, zut_enc to,
                   unsigned char *out) {
  return out ? zut_view_write(v, pos, cnt, to, out) : zut_view_length(v, pos, cnt, to);
}

/* A valid run into a Latin-1 target: code points above U+00FF are
 * unrepresentable, '?' under "replace". */
static int emit_latin1(const zut_view *v, const zut_conv *c, size_t pos,
                       size_t cnt, unsigned char *out, size_t *w, size_t *err) {
  size_t end = pos + cnt, at, len;
  while (pos < end && zut_view_first_wide(v, pos, end - pos, &at, &len)) {
    if (c->policy != ZUT_POLICY_REPLACE) {
      *err = at;
      return ZUT_UNREPRESENTABLE;
    }
    *w += emit(v, pos, at - pos, ZUT_LATIN1, out ? out + *w : NULL);
    *w += zut_replacement(ZUT_LATIN1, out ? out + *w : NULL);
    pos = at + len;
  }
  *w += emit(v, pos, end - pos, ZUT_LATIN1, out ? out + *w : NULL);
  return ZUT_OK;
}

/* Convert the view into out, or measure it when out is NULL. Returns a
 * status; on failure *err is the unit offset of the problem. */
static int convert_view(const zut_view *v, const zut_conv *c, unsigned char *out,
                        size_t *len, size_t *err) {
  size_t w = 0, pos = 0;

  if (c->policy == ZUT_POLICY_REPLACE && c->to == ZUT_UTF8 &&
      is_utf16(v->enc) && c->simdutf_replacement) {
    /* D8: simdutf's own replacement where the C API has one */
    const char16_t *s = (const char16_t *) (const void *) v->base;
    int le = v->enc == ZUT_UTF16LE;
    if (out) {
      w = le ? simdutf_convert_utf16le_to_utf8_with_replacement(s, v->units, (char *) out)
             : simdutf_convert_utf16be_to_utf8_with_replacement(s, v->units, (char *) out);
    } else {
      w = (le ? simdutf_utf8_length_from_utf16le_with_replacement(s, v->units)
              : simdutf_utf8_length_from_utf16be_with_replacement(s, v->units)).count;
    }
  } else {
    for (;;) {
      size_t e = 0;
      int ok = zut_view_validate(v, pos, &e);
      size_t run = (ok ? v->units : e) - pos;
      if (c->to == ZUT_LATIN1) {
        int st = emit_latin1(v, c, pos, run, out, &w, err);
        if (st != ZUT_OK) {
          return st;
        }
      } else {
        w += emit(v, pos, run, c->to, out ? out + w : NULL);
      }
      pos += run;
      if (ok) {
        break;
      }
      if (c->policy != ZUT_POLICY_REPLACE) {
        *err = pos;
        return ZUT_ILL_FORMED;
      }
      w += zut_replacement(c->to, out ? out + w : NULL);
      pos += zut_view_subpart(v, pos);
    }
  }

  if (v->partial) {
    if (c->policy != ZUT_POLICY_REPLACE) {
      *err = v->units;
      return ZUT_ILL_FORMED;
    }
    w += zut_replacement(c->to, out ? out + w : NULL);
  }
  *len = w;
  return ZUT_OK;
}

/* The first U+0000 among whole units, or (size_t) -1. */
static size_t find_nul(const zut_view *v) {
  size_t size = zut_unit_size(v->enc);
  if (size == 1) {
    const char *z = memchr(v->base, 0, v->units);
    return z ? (size_t) (z - v->base) : (size_t) -1;
  }
  for (size_t i = 0; i < v->units; i++) {
    int zero = 1;
    for (size_t b = 0; b < size; b++) {
      zero &= v->base[i * size + b] == 0;
    }
    if (zero) {
      return i;
    }
  }
  return (size_t) -1;
}

/* Byte-order marks first, longest first; then every encoding the bytes are
 * valid in. simdutf's detect_encodings() tries UTF-8, UTF-16LE and UTF-32LE
 * only (*verified 2026-10-13*), so zuutf runs simdutf's validators on all
 * five instead. Returns the BOM's encoding and sets *bom to its length, or
 * returns 0 and sets *mask in simdutf_encoding_type's bits. */
static zut_enc detect_one(zut_scratch *s, const char *p, size_t n, size_t *bom,
                          int *mask) {
  static const struct { const char *b; size_t k; zut_enc e; } boms[] = {
    {"\xEF\xBB\xBF", 3, ZUT_UTF8},
    {"\xFF\xFE\x00\x00", 4, ZUT_UTF32LE},
    {"\x00\x00\xFE\xFF", 4, ZUT_UTF32BE},
    {"\xFF\xFE", 2, ZUT_UTF16LE},
    {"\xFE\xFF", 2, ZUT_UTF16BE},
  };
  static const struct { int bit; zut_enc e; } order[] = {
    {SIMDUTF_ENCODING_UTF8, ZUT_UTF8},
    {SIMDUTF_ENCODING_UTF16_LE, ZUT_UTF16LE},
    {SIMDUTF_ENCODING_UTF16_BE, ZUT_UTF16BE},
    {SIMDUTF_ENCODING_UTF32_LE, ZUT_UTF32LE},
    {SIMDUTF_ENCODING_UTF32_BE, ZUT_UTF32BE},
  };
  for (size_t i = 0; i < sizeof boms / sizeof boms[0]; i++) {
    if (n >= boms[i].k && memcmp(p, boms[i].b, boms[i].k) == 0) {
      *bom = boms[i].k;
      return boms[i].e;
    }
  }
  *bom = 0;
  *mask = 0;
  for (size_t i = 0; i < sizeof order / sizeof order[0]; i++) {
    zut_view v;
    size_t err;
    zut_view_make(&v, s, order[i].e, p, n);
    if (!v.partial && zut_view_validate(&v, 0, &err)) {
      *mask |= order[i].bit;
    }
  }
  return (zut_enc) 0;
}

/* The encoding "auto" chooses: the BOM's, else the first candidate in the
 * order of design §6, else UTF-8 so that the invalid= policy applies. */
static zut_enc resolve_auto(zut_scratch *s, const char **p, size_t *n) {
  static const struct { int bit; zut_enc e; } order[] = {
    {SIMDUTF_ENCODING_UTF8, ZUT_UTF8},
    {SIMDUTF_ENCODING_UTF16_LE, ZUT_UTF16LE},
    {SIMDUTF_ENCODING_UTF16_BE, ZUT_UTF16BE},
    {SIMDUTF_ENCODING_UTF32_LE, ZUT_UTF32LE},
    {SIMDUTF_ENCODING_UTF32_BE, ZUT_UTF32BE},
  };
  size_t bom = 0;
  int mask = 0;
  zut_enc e = detect_one(s, *p, *n, &bom, &mask);
  if (e) {
    *p += bom;
    *n -= bom;
    return e;
  }
  for (size_t i = 0; i < sizeof order / sizeof order[0]; i++) {
    if (mask & order[i].bit) {
      return order[i].e;
    }
  }
  return ZUT_UTF8;
}

static void set_status(double *st, int kind, R_xlen_t i, size_t offset, zut_enc e) {
  st[0] = kind;
  st[1] = (double) i + 1.0;
  st[2] = (double) offset + 1.0;
  st[3] = (double) e;
}

/* mode 0: a list of raw vectors (NULL for NA); mode 1: a character vector
 * marked UTF-8. Returns list(value, status): status is c(kind, index,
 * offset, encoding), kind 0 when every element converted. */
SEXP zut_convert(SEXP x, SEXP from, SEXP to, SEXP policy, SEXP mode,
                 SEXP simdutf_replacement) {
  zut_enc enc = (zut_enc) Rf_asInteger(from);
  zut_conv c;
  c.to = (zut_enc) Rf_asInteger(to);
  c.policy = Rf_asInteger(policy);
  c.simdutf_replacement = Rf_asLogical(simdutf_replacement) == TRUE;
  int chr = Rf_asInteger(mode) == 1;
  R_xlen_t len = zut_length(x);

  zut_scratch scratch;
  scratch.vec = PROTECT(zut_scratch_alloc(zut_max_bytes(x)));
  SEXP value = PROTECT(Rf_allocVector(chr ? STRSXP : VECSXP, len));
  SEXP status = PROTECT(Rf_allocVector(REALSXP, 4));
  double *st = REAL(status);
  memset(st, 0, 4 * sizeof(double));

  /* the output buffer for character results, grown as needed */
  PROTECT_INDEX ipx;
  SEXP buf = R_NilValue;
  PROTECT_WITH_INDEX(buf, &ipx);
  size_t bufcap = 0;

  for (R_xlen_t i = 0; i < len; i++) {
    if (i % ZUT_INTERRUPT_EVERY == ZUT_INTERRUPT_EVERY - 1) {
      R_CheckUserInterrupt();
    }
    const char *p;
    size_t n;
    if (!zut_element(x, i, &p, &n)) {
      if (chr) SET_STRING_ELT(value, i, NA_STRING);
      continue;
    }
    zut_enc e = enc == ZUT_AUTO ? resolve_auto(&scratch, &p, &n) : zut_strip_bom(enc, &p, &n);
    zut_view v;
    zut_view_make(&v, &scratch, e, p, n);

    size_t outlen = 0, err = 0;
    int s = convert_view(&v, &c, NULL, &outlen, &err);
    if (chr) {
      size_t nul = find_nul(&v);
      if (nul != (size_t) -1) {
        int first = s == ZUT_OK || (c.policy == ZUT_POLICY_ERROR && nul < err);
        if (first) {
          s = ZUT_NUL;
          err = nul;
        }
      }
    }
    if (s == ZUT_OK && outlen > (chr ? (size_t) INT_MAX : (size_t) R_XLEN_T_MAX)) {
      s = ZUT_TOO_LONG;
      err = 0;
    }
    if (s != ZUT_OK) {
      if (c.policy == ZUT_POLICY_NA && (s == ZUT_ILL_FORMED || s == ZUT_UNREPRESENTABLE)) {
        if (chr) SET_STRING_ELT(value, i, NA_STRING);
        continue;
      }
      set_status(st, s, i, err, e);
      break;
    }

    if (chr) {
      if (outlen > bufcap) {
        bufcap = outlen;
        REPROTECT(buf = Rf_allocVector(RAWSXP, (R_xlen_t) bufcap), ipx);
      }
      size_t wrote = 0;
      const char *o = "";
      if (outlen) {
        convert_view(&v, &c, RAW(buf), &wrote, &err);
        o = (const char *) RAW(buf);
      }
      SET_STRING_ELT(value, i, Rf_mkCharLenCE(o, (int) wrote, CE_UTF8));
    } else {
      SEXP r = PROTECT(Rf_allocVector(RAWSXP, (R_xlen_t) outlen));
      size_t wrote = 0;
      if (outlen) {
        convert_view(&v, &c, RAW(r), &wrote, &err);
      }
      SET_VECTOR_ELT(value, i, r);
      UNPROTECT(1);
    }
  }

  SEXP out = PROTECT(Rf_allocVector(VECSXP, 2));
  SET_VECTOR_ELT(out, 0, value);
  SET_VECTOR_ELT(out, 1, status);
  UNPROTECT(5);
  return out;
}

/* Per element: -(encoding code) for a BOM, else simdutf's bitmask; NA for a
 * missing element. */
SEXP zut_detect(SEXP x) {
  R_xlen_t len = zut_length(x);
  zut_scratch scratch;
  scratch.vec = PROTECT(zut_scratch_alloc(zut_max_bytes(x)));
  SEXP out = PROTECT(Rf_allocVector(INTSXP, len));
  int *o = INTEGER(out);
  for (R_xlen_t i = 0; i < len; i++) {
    if (i % ZUT_INTERRUPT_EVERY == ZUT_INTERRUPT_EVERY - 1) {
      R_CheckUserInterrupt();
    }
    const char *p;
    size_t n, bom;
    int mask = 0;
    if (!zut_element(x, i, &p, &n)) {
      o[i] = NA_INTEGER;
      continue;
    }
    zut_enc e = detect_one(&scratch, p, n, &bom, &mask);
    o[i] = e ? -(int) e : mask;
  }
  UNPROTECT(2);
  return out;
}
