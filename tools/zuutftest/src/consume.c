/* Calls every member of zuutf_api_v1 through zuutf_api_get(), as a
 * consumer package would (design §7, R10.4). */
#include <stddef.h>
#include <stdint.h>
#include <string.h>

#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>

#define ZUUTF_DEFINE_API_GET
#include <zuutf.h>

/* The table as zuutf 0.1.0 shipped it. Members are appended, never
 * reordered or removed (design §7): every offset here must stay the
 * header's, and the build fails the moment one moves. */
typedef struct {
  uint32_t struct_size;
  zuutf_result (*validate_utf8)(const char *, size_t);
  zuutf_result (*validate_utf16le)(const uint16_t *, size_t);
  zuutf_result (*validate_utf32)(const uint32_t *, size_t);
  int (*validate_ascii)(const char *, size_t);
  size_t (*count_utf8)(const char *, size_t);
  size_t (*utf8_length_from_utf16le)(const uint16_t *, size_t);
  size_t (*utf16_length_from_utf8)(const char *, size_t);
  zuutf_result (*utf16le_to_utf8)(const uint16_t *, size_t, char *, size_t);
  zuutf_result (*utf8_to_utf16le)(const char *, size_t, uint16_t *, size_t);
  zuutf_result (*latin1_to_utf8)(const char *, size_t, char *, size_t);
  size_t (*base64_encoded_length)(size_t, unsigned);
  zuutf_result (*base64_encode)(const unsigned char *, size_t, char *, size_t,
                                unsigned);
  size_t (*base64_decoded_max_length)(const char *, size_t);
  zuutf_result (*base64_decode)(const char *, size_t, unsigned char *, size_t,
                                unsigned);
  const char *(*kernel)(void);
  int (*kernel_ok)(void);
} zuutf_api_0_1_0;

#define FROZEN(member)                                                       \
  _Static_assert(offsetof(zuutf_api_0_1_0, member) == offsetof(zuutf_api, member), \
                 "zuutf_api." #member " moved: members are appended, never reordered")
FROZEN(struct_size);
FROZEN(validate_utf8);
FROZEN(validate_utf16le);
FROZEN(validate_utf32);
FROZEN(validate_ascii);
FROZEN(count_utf8);
FROZEN(utf8_length_from_utf16le);
FROZEN(utf16_length_from_utf8);
FROZEN(utf16le_to_utf8);
FROZEN(utf8_to_utf16le);
FROZEN(latin1_to_utf8);
FROZEN(base64_encoded_length);
FROZEN(base64_encode);
FROZEN(base64_decoded_max_length);
FROZEN(base64_decode);
FROZEN(kernel);
FROZEN(kernel_ok);
_Static_assert(sizeof(zuutf_api) >= sizeof(zuutf_api_0_1_0),
               "zuutf_api lost a member: members are never removed");

static const zuutf_api *api(void) {
  const zuutf_api *a = zuutf_api_get();
  if (a == NULL) {
    Rf_error("zuutf_api_v1 is not registered");
  }
  return a;
}

static SEXP result2(zuutf_result r) {
  SEXP out = PROTECT(Rf_allocVector(REALSXP, 2));
  REAL(out)[0] = r.error;
  REAL(out)[1] = (double) r.count;
  UNPROTECT(1);
  return out;
}

static SEXP result3(zuutf_result r, SEXP buf, size_t unit) {
  SEXP out = PROTECT(Rf_allocVector(VECSXP, 3));
  SET_VECTOR_ELT(out, 0, Rf_ScalarInteger(r.error));
  SET_VECTOR_ELT(out, 1, Rf_ScalarReal((double) r.count));
  if (r.error == ZUUTF_ERR_SUCCESS) {
    SEXP v = PROTECT(Rf_allocVector(RAWSXP, (R_xlen_t) (r.count * unit)));
    if (r.count) memcpy(RAW(v), RAW(buf), r.count * unit);
    SET_VECTOR_ELT(out, 2, v);
    UNPROTECT(1);
  }
  UNPROTECT(1);
  return out;
}

static size_t cap_or(SEXP cap, size_t dflt) {
  return Rf_isNull(cap) ? dflt : (size_t) Rf_asReal(cap);
}

SEXP ztt_struct_size(void) {
  const zuutf_api *a = api();
  SEXP out = PROTECT(Rf_allocVector(REALSXP, 2));
  REAL(out)[0] = a->struct_size;
  REAL(out)[1] = (double) sizeof(zuutf_api);
  UNPROTECT(1);
  return out;
}

SEXP ztt_kernel(void) {
  const zuutf_api *a = api();
  if (!ZUUTF_API_HAS(a, kernel)) Rf_error("no kernel member");
  return Rf_mkString(a->kernel());
}

SEXP ztt_kernel_ok(void) {
  const zuutf_api *a = api();
  if (!ZUUTF_API_HAS(a, kernel_ok)) Rf_error("no kernel_ok member");
  return Rf_ScalarLogical(a->kernel_ok());
}

SEXP ztt_validate(SEXP x, SEXP which) {
  const zuutf_api *a = api();
  const char *w = CHAR(STRING_ELT(which, 0));
  const char *p = (const char *) RAW(x);
  size_t n = (size_t) XLENGTH(x);
  if (strcmp(w, "utf8") == 0) return result2(a->validate_utf8(p, n));
  if (strcmp(w, "utf16le") == 0)
    return result2(a->validate_utf16le((const uint16_t *) (const void *) p, n / 2));
  if (strcmp(w, "utf32") == 0)
    return result2(a->validate_utf32((const uint32_t *) (const void *) p, n / 4));
  if (strcmp(w, "ascii") == 0) return Rf_ScalarLogical(a->validate_ascii(p, n));
  Rf_error("unknown validator");
  return R_NilValue;
}

SEXP ztt_count_utf8(SEXP x) {
  return Rf_ScalarReal((double) api()->count_utf8((const char *) RAW(x), (size_t) XLENGTH(x)));
}

SEXP ztt_convert(SEXP x, SEXP which, SEXP cap) {
  const zuutf_api *a = api();
  const char *w = CHAR(STRING_ELT(which, 0));
  const char *p = (const char *) RAW(x);
  size_t n = (size_t) XLENGTH(x);
  if (strcmp(w, "utf16le_to_utf8") == 0) {
    const uint16_t *s = (const uint16_t *) (const void *) p;
    size_t c = cap_or(cap, a->utf8_length_from_utf16le(s, n / 2));
    SEXP buf = PROTECT(Rf_allocVector(RAWSXP, (R_xlen_t) (c ? c : 1)));
    SEXP out = result3(a->utf16le_to_utf8(s, n / 2, (char *) RAW(buf), c), buf, 1);
    UNPROTECT(1);
    return out;
  }
  if (strcmp(w, "utf8_to_utf16le") == 0) {
    size_t c = cap_or(cap, a->utf16_length_from_utf8(p, n));
    SEXP buf = PROTECT(Rf_allocVector(RAWSXP, (R_xlen_t) (2 * c ? 2 * c : 2)));
    SEXP out = result3(a->utf8_to_utf16le(p, n, (uint16_t *) (void *) RAW(buf), c), buf, 2);
    UNPROTECT(1);
    return out;
  }
  if (strcmp(w, "latin1_to_utf8") == 0) {
    size_t c = cap_or(cap, 2 * n);
    SEXP buf = PROTECT(Rf_allocVector(RAWSXP, (R_xlen_t) (c ? c : 1)));
    SEXP out = result3(a->latin1_to_utf8(p, n, (char *) RAW(buf), c), buf, 1);
    UNPROTECT(1);
    return out;
  }
  Rf_error("unknown conversion");
  return R_NilValue;
}

SEXP ztt_base64_encode(SEXP x, SEXP flags, SEXP cap) {
  const zuutf_api *a = api();
  unsigned f = (unsigned) Rf_asInteger(flags);
  size_t n = (size_t) XLENGTH(x);
  size_t c = cap_or(cap, a->base64_encoded_length(n, f));
  SEXP buf = PROTECT(Rf_allocVector(RAWSXP, (R_xlen_t) (c ? c : 1)));
  SEXP out = result3(a->base64_encode(RAW(x), n, (char *) RAW(buf), c, f), buf, 1);
  UNPROTECT(1);
  return out;
}

SEXP ztt_base64_decode(SEXP x, SEXP flags, SEXP cap) {
  const zuutf_api *a = api();
  unsigned f = (unsigned) Rf_asInteger(flags);
  const char *p = (const char *) RAW(x);
  size_t n = (size_t) XLENGTH(x);
  size_t c = cap_or(cap, a->base64_decoded_max_length(p, n));
  SEXP buf = PROTECT(Rf_allocVector(RAWSXP, (R_xlen_t) (c ? c : 1)));
  SEXP out = result3(a->base64_decode(p, n, RAW(buf), c, f), buf, 1);
  UNPROTECT(1);
  return out;
}

static const R_CallMethodDef calls[] = {
  {"ztt_struct_size", (DL_FUNC) &ztt_struct_size, 0},
  {"ztt_kernel", (DL_FUNC) &ztt_kernel, 0},
  {"ztt_kernel_ok", (DL_FUNC) &ztt_kernel_ok, 0},
  {"ztt_validate", (DL_FUNC) &ztt_validate, 2},
  {"ztt_count_utf8", (DL_FUNC) &ztt_count_utf8, 1},
  {"ztt_convert", (DL_FUNC) &ztt_convert, 3},
  {"ztt_base64_encode", (DL_FUNC) &ztt_base64_encode, 3},
  {"ztt_base64_decode", (DL_FUNC) &ztt_base64_decode, 3},
  {NULL, NULL, 0}
};

void R_init_zuutftest(DllInfo *dll) {
  R_registerRoutines(dll, NULL, calls, NULL, NULL);
  R_useDynamicSymbols(dll, FALSE);
}
