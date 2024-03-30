#define LUA_LIB

#include "bson.h"

namespace lbson {

    thread_local bson thread_bson;

    static int encode(lua_State* L) {
        return thread_bson.encode(L);
    }
    static int decode(lua_State* L) {
        return thread_bson.decode(L);
    }
    static int pairs(lua_State* L) {
        return thread_bson.pairs(L);
    }
    static bson_value* doc() {
        return new bson_value(bson_type::BSON_DOCUMENT, "");
    }
    static bson_value* int32(int32_t value) {
        return new bson_value(bson_type::BSON_INT64, value);
    }
    static bson_value* int64(int64_t value) {
        return new bson_value(bson_type::BSON_INT64, value);
    }
    static bson_value* date(int64_t value) {
        return new bson_value(bson_type::BSON_DATE, value * 1000);
    }
    static bson_value* timestamp(int64_t value) {
        return new bson_value(bson_type::BSON_TIMESTAMP, value);
    }

    static void init_static_bson() {
        for (int i = 0; i < max_bson_index; ++i) {
            char tmp[8];
            bson_numstr_len[i] = sprintf(tmp, "%d", i);
            memcpy(bson_numstrs[i], tmp, bson_numstr_len[i]);
        }
    }

    static codec_base* mongo_codec() {
        mgocodec* codec = new mgocodec();
        codec->set_bson(&thread_bson);
        return codec;
    }

    luakit::lua_table open_lbson(lua_State* L) {
        luakit::kit_state kit_state(L);
        auto llbson = kit_state.new_table("bson");
        llbson.set_function("encode", encode);
        llbson.set_function("decode", decode);
        llbson.set_function("mongocodec", mongo_codec);
        llbson.set_function("timestamp", timestamp);
        llbson.set_function("int32", int32);
        llbson.set_function("int64", int64);
        llbson.set_function("pairs", pairs);
        llbson.set_function("date", date);
        llbson.set_function("doc", doc);
        kit_state.new_class<bson_value>(
            "val", &bson_value::val,
            "str", &bson_value::str,
            "type", &bson_value::type,
            "stype", &bson_value::stype
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
