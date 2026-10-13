/* One element seen as code units (design §4, §6): after the byte-order mark
 * is stripped, UTF-16 aligned, UTF-32 aligned and in native byte order
 * (D13). Validation, counting, lengths and conversion all work on views, in
 * runs of code units, so the replacement loop of D8 can stop and restart at
 * any unit. */
#ifndef ZUT_VIEW_H
#define ZUT_VIEW_H

#include <stddef.h>

#include "zut_input.h"

typedef struct {
  zut_enc enc;      /* concrete; UTF-32 data is native order whatever its label */
  const char *base; /* the code units */
  size_t units;     /* whole code units */
  size_t partial;   /* trailing bytes short of a whole unit */
} zut_view;

/* View n bytes at p in the concrete encoding enc, BOM already stripped. The
 * scratch must hold n bytes. */
void zut_view_make(zut_view *v, zut_scratch *s, zut_enc enc, const char *p,
                   size_t n);

/* Validate units [pos, units). Returns 1 when valid; otherwise 0 with *err
 * the absolute unit offset of the first error. A trailing partial unit is
 * not looked at; see v->partial. */
int zut_view_validate(const zut_view *v, size_t pos, size_t *err);

/* Code points in the valid run of cnt units at pos. */
size_t zut_view_code_points(const zut_view *v, size_t pos, size_t cnt);

/* Bytes the valid run converts to in `to`; one per code point for Latin-1. */
size_t zut_view_length(const zut_view *v, size_t pos, size_t cnt, zut_enc to);

/* Convert the valid run into out, returning the bytes written. For a
 * Latin-1 target every code point of the run must be at most U+00FF. */
size_t zut_view_write(const zut_view *v, size_t pos, size_t cnt, zut_enc to,
                      unsigned char *out);

/* The first code point above U+00FF in the valid run, if any: returns 1 and
 * sets *at (absolute unit offset) and *len (its length in units). */
int zut_view_first_wide(const zut_view *v, size_t pos, size_t cnt, size_t *at,
                        size_t *len);

/* Length in units of the maximal ill-formed subpart starting at pos (one
 * U+FFFD replaces it, as the WHATWG decoder does); at least 1. */
size_t zut_view_subpart(const zut_view *v, size_t pos);

/* The replacement for an ill-formed subpart in `to`: U+FFFD, or '?' for
 * Latin-1. Writes it to out unless out is NULL; returns its length. */
size_t zut_replacement(zut_enc to, unsigned char *out);

int zut_little_endian(void);

#endif
