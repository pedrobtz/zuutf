/* zufast's scalar validator and strict Base64 decoder as an oracle for
 * zuutf (design §10, D12). zufast reports validity and the code points
 * before the first error; the byte offset of the error is where those code
 * points end, which is what zuutf reports. */
#include <stdint.h>
#include <string.h>

#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>

#include <zufast/base64.h>
#include <zufast/utf8.h>

#define ZUUTF_DEFINE_API_GET
#include <zuutf.h>

/* The byte offset after the first k code points of valid UTF-8 at p. */
static size_t skip_code_points(const unsigned char *p, size_t n, size_t k) {
  size_t i = 0;
  while (k-- > 0 && i < n) {
    unsigned char b = p[i];
    i += b < 0x80 ? 1 : b < 0xE0 ? 2 : b < 0xF0 ? 3 : 4;
  }
  return i;
}

/* zufast's view of one string: valid, 0-based error offset, count. */
static void judge(const char *p, size_t n, int *valid, size_t *offset, size_t *count) {
  bool ok = false;
  size_t k = zuf_utf8_count(p, n, &ok);
  *valid = ok;
  *count = k;
  *offset = ok ? 0 : skip_code_points((const unsigned char *) p, n, k);
  if (zuf_utf8_valid(p, n) != ok) {
    Rf_error("zufast disagrees with itself");
  }
}

SEXP zor_utf8(SEXP x) {
  R_xlen_t len = XLENGTH(x);
  SEXP v = PROTECT(Rf_allocVector(LGLSXP, len));
  SEXP o = PROTECT(Rf_allocVector(REALSXP, len));
  SEXP c = PROTECT(Rf_allocVector(REALSXP, len));
  for (R_xlen_t i = 0; i < len; i++) {
    SEXP e = VECTOR_ELT(x, i);
    int ok;
    size_t off, cnt;
    judge((const char *) RAW(e), (size_t) XLENGTH(e), &ok, &off, &cnt);
    LOGICAL(v)[i] = ok;
    REAL(o)[i] = ok ? NA_REAL : (double) off + 1.0;
    REAL(c)[i] = ok ? (double) cnt : NA_REAL;
  }
  SEXP out = PROTECT(Rf_allocVector(VECSXP, 3));
  SET_VECTOR_ELT(out, 0, v);
  SET_VECTOR_ELT(out, 1, o);
  SET_VECTOR_ELT(out, 2, c);
  UNPROTECT(4);
  return out;
}

SEXP zor_base64(SEXP x, SEXP url) {
  R_xlen_t len = XLENGTH(x);
  uint32_t flags = Rf_asLogical(url) == TRUE ? ZUF_B64_URL : 0u;
  SEXP out = PROTECT(Rf_allocVector(VECSXP, len));
  for (R_xlen_t i = 0; i < len; i++) {
    SEXP e = VECTOR_ELT(x, i);
    const char *p = (const char *) RAW(e);
    size_t n = (size_t) XLENGTH(e), cap = zuf_base64_decode_bound(n), got = 0;
    SEXP buf = PROTECT(Rf_allocVector(RAWSXP, (R_xlen_t) (cap ? cap : 1)));
    if (zuf_base64_decode(p, p + n, RAW(buf), cap, &got, flags) == ZUF_OK) {
      SEXP v = PROTECT(Rf_allocVector(RAWSXP, (R_xlen_t) got));
      if (got) memcpy(RAW(v), RAW(buf), got);
      SET_VECTOR_ELT(out, i, v);
      UNPROTECT(1);
    }
    UNPROTECT(1);
  }
  UNPROTECT(1);
  return out;
}

static uint64_t xorshift(uint64_t *s) {
  *s ^= *s << 13;
  *s ^= *s >> 7;
  *s ^= *s << 17;
  return *s;
}

/* One random code point, encoded, at out; returns its length. Every UTF-8
 * length class is common, surrogates excluded. */
static size_t random_code_point(uint64_t *s, unsigned char *out) {
  uint64_t r = xorshift(s);
  uint32_t cp;
  switch (r % 4) {
  case 0: cp = (uint32_t) (r >> 8) % 0x80; break;
  case 1: cp = 0x80 + (uint32_t) (r >> 8) % 0x780; break;
  case 2:
    cp = 0x800 + (uint32_t) (r >> 8) % 0xF800;
    if (cp >= 0xD800 && cp <= 0xDFFF) cp -= 0x800;
    break;
  default: cp = 0x10000 + (uint32_t) (r >> 8) % 0x100000; break;
  }
  if (cp < 0x80) { out[0] = (unsigned char) cp; return 1; }
  if (cp < 0x800) {
    out[0] = (unsigned char) (0xC0 | cp >> 6);
    out[1] = (unsigned char) (0x80 | (cp & 0x3F));
    return 2;
  }
  if (cp < 0x10000) {
    out[0] = (unsigned char) (0xE0 | cp >> 12);
    out[1] = (unsigned char) (0x80 | (cp >> 6 & 0x3F));
    out[2] = (unsigned char) (0x80 | (cp & 0x3F));
    return 3;
  }
  out[0] = (unsigned char) (0xF0 | cp >> 18);
  out[1] = (unsigned char) (0x80 | (cp >> 12 & 0x3F));
  out[2] = (unsigned char) (0x80 | (cp >> 6 & 0x3F));
  out[3] = (unsigned char) (0x80 | (cp & 0x3F));
  return 4;
}

/* A string of up to max_len bytes: valid text, and in about half of them
 * one byte replaced by one of UTF-8's edge values (ASCII, continuation
 * bytes, every kind of lead byte), anywhere, which truncates, overlongs or
 * breaks it, or leaves it valid. */
static size_t random_string(uint64_t *s, unsigned char *buf, size_t max_len) {
  static const unsigned char edges[] = {0x00, 0x41, 0x7F, 0x80, 0xBF, 0xC0, 0xC1,
                                        0xC2, 0xDF, 0xE0, 0xED, 0xEF, 0xF0, 0xF4,
                                        0xF5, 0xFF};
  size_t target = (size_t) (xorshift(s) % (uint64_t) (max_len + 1)), len = 0;
  unsigned char cp[4];
  while (len < target) {
    size_t k = random_code_point(s, cp);
    if (len + k > max_len) break;
    memcpy(buf + len, cp, k);
    len += k;
  }
  uint64_t r = xorshift(s);
  if (len && (r & 1)) buf[(r >> 1) % len] = edges[(r >> 20) % sizeof edges];
  return len;
}

SEXP zor_random(SEXP n_, SEXP max_len_, SEXP seed_) {
  const zuutf_api *api = zuutf_api_get();
  if (api == NULL) Rf_error("zuutf_api_v1 is not registered");
  double n = Rf_asReal(n_);
  int max_len = Rf_asInteger(max_len_);
  uint64_t s = (uint64_t) Rf_asReal(seed_) | 1u;
  unsigned char buf[4096];
  double bad = 0, valid = 0;
  SEXP first = R_NilValue;
  PROTECT_INDEX ipx;
  PROTECT_WITH_INDEX(first, &ipx);
  if (max_len > (int) sizeof buf) max_len = (int) sizeof buf;
  for (double i = 0; i < n; i++) {
    if ((uint64_t) i % 100000 == 0) R_CheckUserInterrupt();
    size_t len = random_string(&s, buf, (size_t) max_len);
    int ok;
    size_t off, cnt;
    judge((const char *) buf, len, &ok, &off, &cnt);
    zuutf_result r = api->validate_utf8((const char *) buf, len);
    int zok = r.error == ZUUTF_ERR_SUCCESS;
    int agree = zok == ok && (ok ? api->count_utf8((const char *) buf, len) == cnt
                                 : r.count == off);
    valid += ok;
    if (!agree) {
      if (bad == 0) {
        SEXP raw = Rf_allocVector(RAWSXP, (R_xlen_t) len);
        REPROTECT(first = raw, ipx);
        if (len) memcpy(RAW(first), buf, len);
      }
      bad++;
    }
  }
  SEXP out = PROTECT(Rf_allocVector(VECSXP, 4));
  SET_VECTOR_ELT(out, 0, Rf_ScalarReal(n));
  SET_VECTOR_ELT(out, 1, Rf_ScalarReal(valid));
  SET_VECTOR_ELT(out, 2, Rf_ScalarReal(bad));
  SET_VECTOR_ELT(out, 3, first);
  SEXP nm = PROTECT(Rf_allocVector(STRSXP, 4));
  SET_STRING_ELT(nm, 0, Rf_mkChar("strings"));
  SET_STRING_ELT(nm, 1, Rf_mkChar("valid"));
  SET_STRING_ELT(nm, 2, Rf_mkChar("disagreements"));
  SET_STRING_ELT(nm, 3, Rf_mkChar("first"));
  Rf_setAttrib(out, R_NamesSymbol, nm);
  UNPROTECT(3);
  return out;
}

static const R_CallMethodDef calls[] = {
  {"zor_utf8", (DL_FUNC) &zor_utf8, 1},
  {"zor_base64", (DL_FUNC) &zor_base64, 2},
  {"zor_random", (DL_FUNC) &zor_random, 3},
  {NULL, NULL, 0}
};

void R_init_zuutforacle(DllInfo *dll) {
  R_registerRoutines(dll, NULL, calls, NULL, NULL);
  R_useDynamicSymbols(dll, FALSE);
}
