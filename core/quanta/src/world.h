#pragma once

#ifdef _MSC_VER
#ifdef WORLD_EXPORT
#define WORLD_API _declspec(dllexport)
#else
#define WORLD_API _declspec(dllimport)
#endif
#else
#define WORLD_API extern
#endif

#ifdef __cplusplus
extern "C" {
#endif

WORLD_API int run_world(const char* fconf);

#ifdef __cplusplus
}
#endif
