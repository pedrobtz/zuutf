/* Embedding R for the fuzz targets: once, with R's signal handlers and C
 * stack check off, since libFuzzer and ASan own both. R_HOME must be set. */
#include <stdlib.h>

#include "fuzz.h"

int zut_fuzz_init(void) {
  static int done = 0;
  char *argv[] = {"R", "--vanilla", "--silent", "--no-echo"};
  if (done) return 0;
  if (!getenv("R_HOME")) return 1;
  R_SignalHandlers = 0;
  Rf_initEmbeddedR(4, argv);
  R_CStackLimit = (uintptr_t) -1;
  done = 1;
  return 0;
}

void zut_fuzz_run(void (*fn)(void *), void *data) {
  /* zuutf's glue raises R errors only for what R refuses (an over-long
   * result) or its own internal failures; on fuzz input either is a
   * finding */
  FUZZ_CHECK(R_ToplevelExec(fn, data));
}

int LLVMFuzzerInitialize(int *argc, char ***argv) {
  (void) argc;
  (void) argv;
  return zut_fuzz_init();
}
