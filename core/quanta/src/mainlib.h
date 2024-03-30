#pragma once

#ifdef _MSC_VER
#ifdef QUANTA_EXPORT
#define QUANTA_API _declspec(dllexport)
#else
#define QUANTA_API _declspec(dllimport)
#endif
#else
#define QUANTA_API extern
#endif

#ifdef __cplusplus
extern "C" {
#endif

QUANTA_API int init_quanta(const char* zfile, const char* fconf);
QUANTA_API int run_quanta();

#ifdef __cplusplus
}
#endif
