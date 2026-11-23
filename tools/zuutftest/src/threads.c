/* zuutf.h promises that every member of zuutf_api_v1 "may be called from
 * any thread" (issue #85: zugodb calls the table from worker threads).
 * This runs the read-only members from several threads at once, on the
 * same and on different buffers, and compares every result with a
 * single-threaded run of the same calls.
 *
 * The threads go first and the reference second, on purpose: in a fresh
 * process the threads' calls are the first the table receives, so they
 * also race on simdutf picking its kernel on first use. No thread calls
 * into R; everything R-side happens in the main thread before the threads
 * start or after they are joined. */
#include <pthread.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include <R.h>
#include <Rinternals.h>

#include <zuutf.h>

const zuutf_api *ztt_api(void); /* src/consume.c */

/* One input's results, as numbers and FNV-1a hashes of what was written. */
typedef struct {
  double v[22];
} outcome;

typedef struct {
  const zuutf_api *api;
  const unsigned char **in;
  const size_t *len;
  int n_in;
  int rounds;
  int id;
  /* filled by the thread */
  outcome *first;   /* n_in outcomes from its first round */
  long unstable;    /* later rounds that disagreed with the first */
  long overruns;    /* guard bytes after an output found changed */
  long failed;      /* allocation failures */
  long calls;
  const char *kernel;
} job;

static pthread_mutex_t gate_mu = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t gate_cv = PTHREAD_COND_INITIALIZER;
static int gate_open = 0;
static int gate_waiting = 0;

#define GUARD 16
#define GUARD_BYTE 0xA5

static uint64_t fnv(const void *p, size_t n) {
  const unsigned char *b = (const unsigned char *) p;
  uint64_t h = 1469598103934665603ULL;
  for (size_t i = 0; i < n; i++) {
    h ^= b[i];
    h *= 1099511628211ULL;
  }
  return h;
}

/* A hash as a double that compares exactly: the low 52 bits. */
static double h52(uint64_t h) {
  return (double) (h & ((1ULL << 52) - 1));
}

/* malloc(n + GUARD) with the guard filled in; the caller checks it. */
static unsigned char *guarded(size_t n) {
  unsigned char *p = (unsigned char *) malloc(n + GUARD);
  if (p) memset(p + n, GUARD_BYTE, GUARD);
  return p;
}

static int guard_ok(const unsigned char *p, size_t n) {
  for (size_t i = 0; i < GUARD; i++) {
    if (p[n + i] != GUARD_BYTE) return 0;
  }
  return 1;
}

/* Every read-only member, on one input. Returns 0 on allocation failure. */
static int run_one(const zuutf_api *a, const unsigned char *s, size_t n,
                   unsigned flags, outcome *o, long *overruns, long *calls) {
  const char *c = (const char *) s;
  memset(o, 0, sizeof *o);

  zuutf_result r = a->validate_utf8(c, n);
  o->v[0] = r.error;
  o->v[1] = (double) r.count;
  o->v[2] = a->validate_ascii(c, n);
  *calls += 2;
  int valid8 = r.error == ZUUTF_ERR_SUCCESS;

  if (valid8) {
    o->v[3] = (double) a->count_utf8(c, n);
    size_t u16 = a->utf16_length_from_utf8(c, n);
    o->v[4] = (double) u16;
    *calls += 2;

    unsigned char *w = guarded(2 * u16);
    if (!w) return 0;
    r = a->utf8_to_utf16le(c, n, (uint16_t *) (void *) w, u16);
    o->v[5] = r.error;
    o->v[6] = (double) r.count;
    o->v[7] = h52(fnv(w, 2 * r.count));
    if (!guard_ok(w, 2 * u16)) (*overruns)++;
    *calls += 1;

    zuutf_result v16 = a->validate_utf16le((const uint16_t *) (void *) w, r.count);
    o->v[8] = v16.error;
    size_t back = a->utf8_length_from_utf16le((const uint16_t *) (void *) w, r.count);
    o->v[9] = (double) back;
    *calls += 2;

    unsigned char *b = guarded(back);
    if (!b) {
      free(w);
      return 0;
    }
    r = a->utf16le_to_utf8((const uint16_t *) (void *) w, v16.count, (char *) b, back);
    o->v[10] = r.error;
    o->v[11] = r.count == n && memcmp(b, s, n) == 0;
    if (!guard_ok(b, back)) (*overruns)++;
    *calls += 1;

    /* A capacity one short must refuse, and write nothing past it. */
    if (back > 0) {
      unsigned char *t = guarded(back - 1);
      if (!t) {
        free(b);
        free(w);
        return 0;
      }
      r = a->utf16le_to_utf8((const uint16_t *) (void *) w, v16.count, (char *) t, back - 1);
      o->v[12] = r.error;
      o->v[13] = (double) r.count;
      if (!guard_ok(t, back - 1)) (*overruns)++;
      *calls += 1;
      free(t);
    }
    free(b);
    free(w);
  }

  /* UTF-32 over the input's whole 4-byte units, valid or not. */
  if (n >= 4) {
    uint32_t *u = (uint32_t *) malloc((n / 4) * sizeof *u);
    if (!u) return 0;
    memcpy(u, s, (n / 4) * sizeof *u);
    r = a->validate_utf32(u, n / 4);
    o->v[14] = r.error;
    o->v[15] = (double) r.count;
    *calls += 1;
    free(u);
  }

  /* Latin-1: every byte string is valid. */
  unsigned char *l = guarded(2 * n);
  if (!l) return 0;
  r = a->latin1_to_utf8(c, n, (char *) l, 2 * n);
  o->v[16] = (double) r.count;
  o->v[17] = h52(fnv(l, r.count));
  if (!guard_ok(l, 2 * n)) (*overruns)++;
  *calls += 1;
  free(l);

  /* Base64 there and back, then the input itself read as Base64 text. */
  size_t elen = a->base64_encoded_length(n, flags);
  unsigned char *e = guarded(elen);
  if (!e) return 0;
  r = a->base64_encode(s, n, (char *) e, elen, flags);
  o->v[18] = h52(fnv(e, r.count)) + r.error;
  if (!guard_ok(e, elen)) (*overruns)++;
  size_t dmax = a->base64_decoded_max_length((const char *) e, r.count);
  unsigned char *d = guarded(dmax);
  if (!d) {
    free(e);
    return 0;
  }
  zuutf_result rd = a->base64_decode((const char *) e, r.count, d, dmax,
                                     flags & ZUUTF_BASE64_URL);
  o->v[19] = rd.error == ZUUTF_ERR_SUCCESS && rd.count == n && memcmp(d, s, n) == 0;
  if (!guard_ok(d, dmax)) (*overruns)++;
  *calls += 4;
  free(d);
  free(e);

  dmax = a->base64_decoded_max_length(c, n);
  d = guarded(dmax);
  if (!d) return 0;
  rd = a->base64_decode(c, n, d, dmax, ZUUTF_BASE64_STRICT);
  o->v[20] = rd.error;
  o->v[21] = (double) rd.count;
  if (!guard_ok(d, dmax)) (*overruns)++;
  *calls += 2;
  free(d);
  return 1;
}

static unsigned flags_for(int i) {
  return (i % 2) ? (ZUUTF_BASE64_URL | ZUUTF_BASE64_NO_PAD) : 0u;
}

static void *worker(void *arg) {
  job *j = (job *) arg;

  pthread_mutex_lock(&gate_mu);
  gate_waiting++;
  while (!gate_open) pthread_cond_wait(&gate_cv, &gate_mu);
  pthread_mutex_unlock(&gate_mu);

  outcome o;
  for (int round = 0; round < j->rounds; round++) {
    /* Each thread walks the inputs from a different start, so threads
     * share buffers and also work on different ones at the same time. */
    for (int k = 0; k < j->n_in; k++) {
      int i = (k + j->id) % j->n_in;
      if (!run_one(j->api, j->in[i], j->len[i], flags_for(i), &o, &j->overruns,
                   &j->calls)) {
        j->failed++;
        continue;
      }
      if (round == 0) {
        j->first[i] = o;
      } else if (memcmp(&o, &j->first[i], sizeof o) != 0) {
        j->unstable++;
      }
    }
  }
  j->kernel = j->api->kernel();
  return NULL;
}

SEXP ztt_threads(SEXP inputs, SEXP nthreads, SEXP rounds) {
  const zuutf_api *a = ztt_api();
  if (a == NULL) Rf_error("zuutf_api_v1 is not registered");
  if (TYPEOF(inputs) != VECSXP) Rf_error("inputs must be a list of raw vectors");
  int n_in = Rf_length(inputs);
  int nt = Rf_asInteger(nthreads);
  int nr = Rf_asInteger(rounds);
  if (n_in < 1 || nt < 1 || nt > 256 || nr < 1) Rf_error("bad arguments");

  /* R_alloc'd memory is freed by R when this call returns, error or not. */
  const unsigned char **in = (const unsigned char **) R_alloc(n_in, sizeof *in);
  size_t *len = (size_t *) R_alloc(n_in, sizeof *len);
  for (int i = 0; i < n_in; i++) {
    SEXP x = VECTOR_ELT(inputs, i);
    if (TYPEOF(x) != RAWSXP) Rf_error("inputs must be a list of raw vectors");
    in[i] = RAW(x);
    len[i] = (size_t) XLENGTH(x);
  }
  job *jobs = (job *) R_alloc(nt, sizeof *jobs);
  pthread_t *tid = (pthread_t *) R_alloc(nt, sizeof *tid);
  for (int t = 0; t < nt; t++) {
    jobs[t] = (job) {a, in, len, n_in, nr, t, NULL, 0, 0, 0, 0, NULL};
    jobs[t].first = (outcome *) R_alloc(n_in, sizeof(outcome));
    memset(jobs[t].first, 0, n_in * sizeof(outcome));
  }

  /* From here to the join, no R call: an R error would leave threads
   * running over R memory. */
  gate_open = 0;
  gate_waiting = 0;
  int started = 0;
  for (; started < nt; started++) {
    if (pthread_create(&tid[started], NULL, worker, &jobs[started]) != 0) break;
  }
  /* Open the gate once every thread waits at it, so the first calls into
   * the table are made together. */
  for (;;) {
    pthread_mutex_lock(&gate_mu);
    int ready = gate_waiting == started;
    if (ready) {
      gate_open = 1;
      pthread_cond_broadcast(&gate_cv);
    }
    pthread_mutex_unlock(&gate_mu);
    if (ready) break;
  }
  for (int t = 0; t < started; t++) pthread_join(tid[t], NULL);

  /* The reference: the same calls, single-threaded, after the threads. */
  long mismatched = 0, unstable = 0, overruns = 0, failed = 0, calls = 0;
  long kernel_differs = 0, ref_overruns = 0, ref_calls = 0;
  const char *kernel = a->kernel();
  for (int i = 0; i < n_in; i++) {
    outcome ref;
    if (!run_one(a, in[i], len[i], flags_for(i), &ref, &ref_overruns, &ref_calls)) {
      failed++;
      continue;
    }
    for (int t = 0; t < started; t++) {
      if (memcmp(&ref, &jobs[t].first[i], sizeof ref) != 0) mismatched++;
    }
  }
  for (int t = 0; t < started; t++) {
    unstable += jobs[t].unstable;
    overruns += jobs[t].overruns;
    failed += jobs[t].failed;
    calls += jobs[t].calls;
    if (jobs[t].kernel == NULL || strcmp(jobs[t].kernel, kernel) != 0) kernel_differs++;
  }

  const char *names[] = {"threads", "calls", "mismatched", "unstable",
                         "overruns", "failed", "kernel_differs", ""};
  SEXP out = PROTECT(Rf_mkNamed(VECSXP, names));
  SET_VECTOR_ELT(out, 0, Rf_ScalarInteger(started));
  SET_VECTOR_ELT(out, 1, Rf_ScalarReal((double) calls));
  SET_VECTOR_ELT(out, 2, Rf_ScalarReal((double) mismatched));
  SET_VECTOR_ELT(out, 3, Rf_ScalarReal((double) unstable));
  SET_VECTOR_ELT(out, 4, Rf_ScalarReal((double) (overruns + ref_overruns)));
  SET_VECTOR_ELT(out, 5, Rf_ScalarReal((double) failed));
  SET_VECTOR_ELT(out, 6, Rf_ScalarReal((double) kernel_differs));
  UNPROTECT(1);
  return out;
}
