#define LUA_LIB

#include "ljson.h"

namespace ljson {
    thread_local yyjson tjson;
    
    static codec_base* json_codec(bool numkey, bool empty_as_arr) {
        jsoncodec* codec = new jsoncodec();
        codec->set_empty_as_arr(empty_as_arr);
        codec->set_numkeydisable(numkey);
        codec->set_json(&tjson);
        return codec;
    }

    luakit::lua_table open_ljson(lua_State* L) {
        luakit::kit_state kit_state(L);
        auto ljson = kit_state.new_table("json");
        ljson.set_function("jsoncodec", json_codec);
        ljson.set_function("realloc", [](size_t sz) { return tjson.reset_alc(sz); });
        ljson.set_function("pretty", [](lua_State* L) { return tjson.pretty(L); });
        ljson.set_function("encode", [](lua_State* L) { return tjson.encode(L); });
        ljson.set_function("decode", [](lua_State* L) { return tjson.decode(L); });
        return ljson;
    }
}

extern "C" {
    LUALIB_API int luaopen_ljson(lua_State* L) {
        auto ljson = ljson::open_ljson(L);
        return ljson.push_stack();
    }
}