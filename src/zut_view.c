/* Views and runs of code units over simdutf's C API (design §4, §6). */
#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>
#include <stdint.h>
#include <string.h>

#include "simdutf_c.h"
#include "zut_view.h"

#define U16(v) ((const char16_t *) (const void *) (v)->base)
#define U32(v) ((const char32_t *) (const void *) (v)->base)
#define OUT16(o) ((char16_t *) (void *) (o))
#define OUT32(o) ((char32_t *) (void *) (o))

int zut_little_endian(void) {
  const uint16_t one = 1;
  return *(const unsigned char *) &one == 1;
}

static int is_utf16(zut_enc e) { return e == ZUT_UTF16LE || e == ZUT_UTF16BE; }
static int is_utf32(zut_enc e) { return e == ZUT_UTF32LE || e == ZUT_UTF32BE; }

static void swap16(unsigned char *out, const unsigned char *in, size_t units) {
  for (size_t i = 0; i < units; i++) {
    unsigned char a = in[2 * i];
    out[2 * i] = in[2 * i + 1];
    out[2 * i + 1] = a;
  }
}

static void swap32_in_place(unsigned char *p, size_t units) {
  for (size_t i = 0; i < units; i++) {
    unsigned char a = p[4 * i], b = p[4 * i + 1];
    p[4 * i] = p[4 * i + 3];
    p[4 * i + 1] = p[4 * i + 2];
    p[4 * i + 2] = b;
    p[4 * i + 3] = a;
  }
}

void zut_view_make(zut_view *v, zut_scratch *s, zut_enc enc, const char *p,
                   size_t n) {
  size_t size = zut_unit_size(enc);
  v->enc = enc;
  v->units = n / size;
  v->partial = n % size;
  if (is_utf16(enc)) {
    v->base = (const char *) zut_as_utf16(s, p, v->units);
  } else if (is_utf32(enc)) {
    v->base = (const char *) zut_as_utf32(s, enc, p, v->units);
  } else {
    v->base = p;
  }
}

int zut_view_validate(const zut_view *v, size_t pos, size_t *err) {
  size_t rest = v->units - pos;
  simdutf_result r = {SIMDUTF_ERROR_SUCCESS, 0};
  switch (v->enc) {
  case ZUT_UTF8:
    r = simdutf_validate_utf8_with_errors(v->base + pos, rest);
    break;
  case ZUT_ASCII:
    r = simdutf_validate_ascii_with_errors(v->base + pos, rest);
    break;
  case ZUT_UTF16LE:
    r = simdutf_validate_utf16le_with_errors(U16(v) + pos, rest);
    break;
  case ZUT_UTF16BE:
    r = simdutf_validate_utf16be_with_errors(U16(v) + pos, rest);
    break;
  case ZUT_UTF32LE:
  case ZUT_UTF32BE:
    r = simdutf_validate_utf32_with_errors(U32(v) + pos, rest);
    break;
  default: /* Latin-1: every byte string */
    break;
  }
  if (r.error != SIMDUTF_ERROR_SUCCESS) {
    *err = pos + r.count;
    return 0;
  }
  return 1;
}

size_t zut_view_code_points(const zut_view *v, size_t pos, size_t cnt) {
  switch (v->enc) {
  case ZUT_UTF8:
    return simdutf_count_utf8(v->base + pos, cnt);
  case ZUT_UTF16LE:
    return simdutf_count_utf16le(U16(v) + pos, cnt);
  case ZUT_UTF16BE:
    return simdutf_count_utf16be(U16(v) + pos, cnt);
  default: /* UTF-32, Latin-1, ASCII: a unit is a code point */
    return cnt;
  }
}

static size_t utf32_supplementary(const char32_t *s, size_t n) {
  size_t k = 0;
  for (size_t i = 0; i < n; i++) {
    k += s[i] > 0xFFFF;
  }
  return k;
}

size_t zut_view_length(const zut_view *v, size_t pos, size_t cnt, zut_enc to) {
  if (to == ZUT_LATIN1) {
    return zut_view_code_points(v, pos, cnt);
  }
  if (is_utf32(to)) {
    return 4 * zut_view_code_points(v, pos, cnt);
  }
  if (to == ZUT_UTF8) {
    switch (v->enc) {
    case ZUT_LATIN1:
      return simdutf_utf8_length_from_latin1(v->base + pos, cnt);
    case ZUT_UTF16LE:
      return simdutf_utf8_length_from_utf16le(U16(v) + pos, cnt);
    case ZUT_UTF16BE:
      return simdutf_utf8_length_from_utf16be(U16(v) + pos, cnt);
    case ZUT_UTF32LE:
    case ZUT_UTF32BE:
      return simdutf_utf8_length_from_utf32(U32(v) + pos, cnt);
    default:
      return cnt;
    }
  }
  /* UTF-16, either order */
  switch (v->enc) {
  case ZUT_UTF8:
  case ZUT_ASCII:
    return 2 * simdutf_utf16_length_from_utf8(v->base + pos, cnt);
  case ZUT_UTF32LE:
  case ZUT_UTF32BE:
    return 2 * (cnt + utf32_supplementary(U32(v) + pos, cnt));
  default: /* Latin-1, UTF-16 */
    return 2 * cnt;
  }
}

static size_t write_utf8(const zut_view *v, size_t pos, size_t cnt, char *out,
                         size_t cap) {
  switch (v->enc) {
  case ZUT_LATIN1:
    return simdutf_convert_latin1_to_utf8_safe(v->base + pos, cnt, out, cap);
  case ZUT_UTF16LE:
    return simdutf_convert_valid_utf16le_to_utf8(U16(v) + pos, cnt, out);
  case ZUT_UTF16BE:
    return simdutf_convert_valid_utf16be_to_utf8(U16(v) + pos, cnt, out);
  case ZUT_UTF32LE:
  case ZUT_UTF32BE:
    return simdutf_convert_valid_utf32_to_utf8(U32(v) + pos, cnt, out);
  default:
    memcpy(out, v->base + pos, cnt);
    return cnt;
  }
}

static size_t write_utf16(const zut_view *v, size_t pos, size_t cnt, int le,
                          unsigned char *out) {
  switch (v->enc) {
  case ZUT_UTF8:
  case ZUT_ASCII:
    return 2 * (le ? simdutf_convert_valid_utf8_to_utf16le(v->base + pos, cnt, OUT16(out))
                   : simdutf_convert_valid_utf8_to_utf16be(v->base + pos, cnt, OUT16(out)));
  case ZUT_LATIN1:
    return 2 * (le ? simdutf_convert_latin1_to_utf16le(v->base + pos, cnt, OUT16(out))
                   : simdutf_convert_latin1_to_utf16be(v->base + pos, cnt, OUT16(out)));
  case ZUT_UTF16LE:
  case ZUT_UTF16BE: {
    const unsigned char *in = (const unsigned char *) (U16(v) + pos);
    if ((v->enc == ZUT_UTF16LE) == le) {
      memcpy(out, in, 2 * cnt);
    } else {
      swap16(out, in, cnt);
    }
    return 2 * cnt;
  }
  default: /* UTF-32 */
    return 2 * (le ? simdutf_convert_utf32_to_utf16le(U32(v) + pos, cnt, OUT16(out))
                   : simdutf_convert_utf32_to_utf16be(U32(v) + pos, cnt, OUT16(out)));
  }
}

static size_t write_utf32(const zut_view *v, size_t pos, size_t cnt, int le,
                          unsigned char *out) {
  size_t units;
  switch (v->enc) {
  case ZUT_UTF8:
  case ZUT_ASCII:
    units = simdutf_convert_valid_utf8_to_utf32(v->base + pos, cnt, OUT32(out));
    break;
  case ZUT_LATIN1:
    units = simdutf_convert_latin1_to_utf32(v->base + pos, cnt, OUT32(out));
    break;
  case ZUT_UTF16LE:
    units = simdutf_convert_valid_utf16le_to_utf32(U16(v) + pos, cnt, OUT32(out));
    break;
  case ZUT_UTF16BE:
    units = simdutf_convert_valid_utf16be_to_utf32(U16(v) + pos, cnt, OUT32(out));
    break;
  default: /* UTF-32: already native */
    memcpy(out, U32(v) + pos, 4 * cnt);
    units = cnt;
    break;
  }
  if (le != zut_little_endian()) {
    swap32_in_place(out, units);
  }
  return 4 * units;
}

static size_t write_latin1(const zut_view *v, size_t pos, size_t cnt, char *out) {
  switch (v->enc) {
  case ZUT_UTF8:
    return simdutf_convert_valid_utf8_to_latin1(v->base + pos, cnt, out);
  case ZUT_UTF16LE:
    return simdutf_convert_valid_utf16le_to_latin1(U16(v) + pos, cnt, out);
  case ZUT_UTF16BE:
    return simdutf_convert_valid_utf16be_to_latin1(U16(v) + pos, cnt, out);
  case ZUT_UTF32LE:
  case ZUT_UTF32BE:
    /* the C API has no convert_valid_utf32_to_latin1; the run is valid and
     * narrow, so this cannot fail */
    return simdutf_convert_utf32_to_latin1_with_errors(U32(v) + pos, cnt, out).count;
  default:
    memcpy(out, v->base + pos, cnt);
    return cnt;
  }
}

size_t zut_view_write(const zut_view *v, size_t pos, size_t cnt, zut_enc to,
                      unsigned char *out, size_t cap) {
  if (cnt == 0) {
    return 0;
  }
  switch (to) {
  case ZUT_UTF8:
    return write_utf8(v, pos, cnt, (char *) out, cap);
  case ZUT_UTF16LE:
  case ZUT_UTF16BE:
    return write_utf16(v, pos, cnt, to == ZUT_UTF16LE, out);
  case ZUT_UTF32LE:
  case ZUT_UTF32BE:
    return write_utf32(v, pos, cnt, to == ZUT_UTF32LE, out);
  default:
    return write_latin1(v, pos, cnt, (char *) out);
  }
}

int zut_view_first_wide(const zut_view *v, size_t pos, size_t cnt, size_t *at,
                        size_t *len) {
  size_t end = pos + cnt;
  switch (v->enc) {
  case ZUT_UTF8: {
    /* in valid UTF-8 every byte from 0xC4 up leads a code point >= U+0100;
     * continuation bytes are 0x80-0xBF */
    const unsigned char *s = (const unsigned char *) v->base;
    for (size_t i = pos; i < end; i++) {
      if (s[i] >= 0xC4) {
        *at = i;
        *len = s[i] >= 0xF0 ? 4 : s[i] >= 0xE0 ? 3 : 2;
        return 1;
      }
    }
    return 0;
  }
  case ZUT_UTF16LE:
  case ZUT_UTF16BE: {
    const unsigned char *s = (const unsigned char *) v->base;
    int le = v->enc == ZUT_UTF16LE;
    for (size_t i = pos; i < end; i++) {
      unsigned u = le ? (unsigned) s[2 * i] | (unsigned) s[2 * i + 1] << 8
                      : (unsigned) s[2 * i] << 8 | (unsigned) s[2 * i + 1];
      if (u > 0xFF) {
        *at = i;
        *len = (u >= 0xD800 && u <= 0xDBFF) ? 2 : 1;
        return 1;
      }
    }
    return 0;
  }
  case ZUT_UTF32LE:
  case ZUT_UTF32BE: {
    const char32_t *s = U32(v);
    for (size_t i = pos; i < end; i++) {
      if (s[i] > 0xFF) {
        *at = i;
        *len = 1;
        return 1;
      }
    }
    return 0;
  }
  default:
    return 0;
  }
}

/* Unicode's "maximal subpart of an ill-formed subsequence" (Unicode §3.9,
 * Table 3-7), which the WHATWG decoder replaces with one U+FFFD. */
static size_t utf8_subpart(const unsigned char *s, size_t n) {
  unsigned char b = s[0];
  size_t need;
  unsigned char lo = 0x80, hi = 0xBF;
  if (b >= 0xC2 && b <= 0xDF) {
    need = 1;
  } else if (b >= 0xE0 && b <= 0xEF) {
    need = 2;
    if (b == 0xE0) lo = 0xA0;
    if (b == 0xED) hi = 0x9F;
  } else if (b >= 0xF0 && b <= 0xF4) {
    need = 3;
    if (b == 0xF0) lo = 0x90;
    if (b == 0xF4) hi = 0x8F;
  } else {
    return 1;
  }
  size_t k = 1;
  for (; k <= need && k < n; k++) {
    unsigned char c = s[k];
    if (c < lo || c > hi) {
      break;
    }
    lo = 0x80;
    hi = 0xBF;
  }
  return k;
}

size_t zut_view_subpart(const zut_view *v, size_t pos) {
  if (v->enc == ZUT_UTF8) {
    return utf8_subpart((const unsigned char *) v->base + pos, v->units - pos);
  }
  return 1; /* an unpaired surrogate, an out-of-range UTF-32 unit */
}

size_t zut_replacement(zut_enc to, unsigned char *out) {
  static const unsigned char utf8[] = {0xEF, 0xBF, 0xBD};
  static const unsigned char le16[] = {0xFD, 0xFF};
  static const unsigned char be16[] = {0xFF, 0xFD};
  static const unsigned char le32[] = {0xFD, 0xFF, 0x00, 0x00};
  static const unsigned char be32[] = {0x00, 0x00, 0xFF, 0xFD};
  static const unsigned char q[] = {0x3F};
  const unsigned char *r;
  size_t n;
  switch (to) {
  case ZUT_UTF8: r = utf8; n = 3; break;
  case ZUT_UTF16LE: r = le16; n = 2; break;
  case ZUT_UTF16BE: r = be16; n = 2; break;
  case ZUT_UTF32LE: r = le32; n = 4; break;
  case ZUT_UTF32BE: r = be32; n = 4; break;
  default: r = q; n = 1; break;
  }
  if (out) {
    memcpy(out, r, n);
  }
  return n;
}
