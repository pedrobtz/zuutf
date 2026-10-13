/* The C side of the one C++ shim (design §4, D10): what simdutf's C API
 * cannot say about kernels. No C++ type crosses this header. */
#ifndef ZUT_IMPL_H
#define ZUT_IMPL_H

#ifdef __cplusplus
extern "C" {
#endif

/* simdutf's version string, "9.2.1". */
const char *zut_simdutf_version(void);

/* The active kernel's name. The first call runs simdutf's CPU detection,
 * which honours SIMDUTF_FORCE_IMPLEMENTATION; "unsupported" means a forced
 * name that is unknown or that this CPU cannot run. */
const char *zut_active_kernel(void);

/* 1 when the active kernel is a real one this CPU can run. simdutf makes a
 * kernel named by SIMDUTF_FORCE_IMPLEMENTATION active without asking the
 * CPU, so a forced kernel the CPU lacks would die of an illegal instruction
 * on its first call; this asks without running any of its code. */
int zut_active_kernel_ok(void);

/* The kernels compiled in, in simdutf's order, and for each its description
 * and whether this CPU can run it. Indices run from 0 to count - 1. */
int zut_kernel_count(void);
const char *zut_kernel_name(int i);
const char *zut_kernel_description(int i);
int zut_kernel_supported(int i);

/* Make the named kernel active. Returns 1 on success, 0 when the name is not
 * compiled in or this CPU cannot run it; the active kernel is then
 * unchanged. For tests only (design §10). */
int zut_force_kernel(const char *name);

#ifdef __cplusplus
}
#endif

#endif
