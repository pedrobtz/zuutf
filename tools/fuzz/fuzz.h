/* Shared by zuutf's libFuzzer targets (design §10). Each target embeds R
 * once and drives zuutf's own .Call entry points, so what is fuzzed is the
 * glue R calls, simdutf included, under ASan and UBSan.
 *
 * FUZZ_CHECK(cond) traps when cond is false: a broken invariant is a
 * finding. Built with -DZUT_FUZZ_CANARY, every target also traps as soon as
 * it accepts an input, which tools/fuzz/canary.input guarantees: a target is
 * trusted only once its canary has been seen to crash (tools/run-fuzz). */
#ifndef ZUT_FUZZ_H
#define ZUT_FUZZ_H

#include <stddef.h>
#include <stdint.h>
#include <string.h>

#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>
#include <Rembedded.h>
#define R_INTERFACE_PTRS
#define CSTACK_DEFNS
#include <Rinterface.h>

#include "zut_r.h"

#define FUZZ_CHECK(cond)          \
  do {                            \
    if (!(cond)) __builtin_trap(); \
  } while (0)

#ifdef ZUT_FUZZ_CANARY
#define FUZZ_ACCEPTED() __builtin_trap()
#else
#define FUZZ_ACCEPTED() ((void) 0)
#endif

/* A cursor over the input that yields 0 once it is spent. */
typedef struct {
  const uint8_t *p;
  size_t n, i;
} zut_fuzz_in;

static inline uint8_t zut_fuzz_u8(zut_fuzz_in *in) {
  return in->i < in->n ? in->p[in->i++] : 0;
}

/* The rest of the input as a raw vector; the caller protects it. */
static inline SEXP zut_fuzz_rest(zut_fuzz_in *in) {
  size_t m = in->n - in->i;
  SEXP x = Rf_allocVector(RAWSXP, (R_xlen_t) m);
  if (m) memcpy(RAW(x), in->p + in->i, m);
  in->i = in->n;
  return x;
}

int zut_fuzz_init(void);

/* Run fn(data) under R_ToplevelExec, so that an R error is a finding (it
 * traps) rather than a jump to R's top level. */
void zut_fuzz_run(void (*fn)(void *), void *data);

#endif
