
#pragma once

#ifdef _WIN32
	#define UTILITY_EXPORT __declspec (dllexport)
	#ifndef fileno
	#define fileno(f) (_fileno(f))
	#endif
#else
	#define UTILITY_EXPORT
#endif

#ifdef __cplusplus
extern "C" {
#endif

	UTILITY_EXPORT  int luaopen_util(lua_State *L);

#ifdef __cplusplus
}
#endif