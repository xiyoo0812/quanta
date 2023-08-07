#define LUA_LIB

#include "ljson.h"

namespace ljson {
    thread_local yyjson lyyjson;
    luakit::lua_table open_ljson(lua_State* L) {
        luakit::kit_state kit_state(L);
        auto ljson = kit_state.new_table();
        ljson.set_function("pretty", [](lua_State* L){ return lyyjson.pretty(L); });
        ljson.set_function("encode", [](lua_State* L){ return lyyjson.encode(L); });
        ljson.set_function("decode", [](lua_State* L){ return lyyjson.decode(L); });
        return ljson;
    }
}

extern "C" {
    LUALIB_API int luaopen_ljson(lua_State* L) {
        auto ljson = ljson::open_ljson(L);
        return ljson.push_stack();
    }
}