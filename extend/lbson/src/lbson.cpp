#define LUA_LIB

#include "bson.h"

namespace lbson {

    thread_local bson tbson;

    static int encode(lua_State* L) {
        return tbson.encode(L);
    }
    static int decode(lua_State* L) {
        return tbson.decode(L);
    }
    static int pairs(lua_State* L) {
        return tbson.pairs(L);
    }
    static int regex(lua_State* L) {
        return tbson.regex(L);
    }
    static int binary(lua_State* L) {
        return tbson.binary(L);
    }
    static int objectid(lua_State* L) {
        return tbson.objectid(L);
    }
    static int int64(lua_State* L, int64_t value) {
        return tbson.int64(L, value);
    }
    static int date(lua_State* L, int64_t value) {
        return tbson.date(L, value * 1000);
    }

    static void init_static_bson() {
        for (uint32_t i = 0; i < max_bson_index; ++i) {
            bson_numstr_len[i] = std::format_to_n(bson_numstrs[i], 4, "{}", i).size;
        }
    }

    static codec_base* mongo_codec(lua_State* L) {
        mgocodec* codec = new mgocodec();
        codec->set_buff(luakit::get_buff());
        codec->set_bson(&tbson);
        return codec;
    }

    luakit::lua_table open_lbson(lua_State* L) {
        luakit::kit_state kit_state(L);
        tbson.set_buff(luakit::get_buff());
        auto llbson = kit_state.new_table("bson");
        llbson.set_function("mongocodec", mongo_codec);
        llbson.set_function("objectid", objectid);
        llbson.set_function("encode", encode);
        llbson.set_function("decode", decode);
        llbson.set_function("binary", binary);
        llbson.set_function("int64", int64);
        llbson.set_function("pairs", pairs);
        llbson.set_function("regex", regex);
        llbson.set_function("date", date);
        llbson.new_enum("BSON_TYPE",
            "BSON_EOO", BSON_EOO,
            "BSON_REAL", BSON_REAL,
            "BSON_STRING", BSON_STRING,
            "BSON_DOCUMENT", BSON_DOCUMENT,
            "BSON_ARRAY", BSON_ARRAY,
            "BSON_BINARY", BSON_BINARY,
            "BSON_OBJECTID", BSON_OBJECTID,
            "BSON_BOOLEAN", BSON_BOOLEAN,
            "BSON_DATE", BSON_DATE,
            "BSON_NULL", BSON_NULL,
            "BSON_REGEX", BSON_REGEX,
            "BSON_JSCODE", BSON_JSCODE,
            "BSON_INT32", BSON_INT32,
            "BSON_INT64", BSON_INT64,
            "BSON_INT128", BSON_INT128,
            "BSON_MINKEY", BSON_MINKEY,
            "BSON_MAXKEY", BSON_MAXKEY
        );
        return llbson;
    }
}

extern "C" {
    LUALIB_API int luaopen_lbson(lua_State* L) {
        lbson::init_static_bson();
        auto lluabus = lbson::open_lbson(L);
        return lluabus.push_stack();
    }
}
