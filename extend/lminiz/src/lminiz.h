#pragma once

#include "lua_kit.h"

extern "C" {

    LUALIB_API bool lua_initzip(lua_State* L, const char* zfile);

    LUALIB_API void lua_closezip();
}
