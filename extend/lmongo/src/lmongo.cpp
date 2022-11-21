#define LUA_LIB

#include "bson.h"
#include "mongo.h"

using namespace lcodec;

namespace lmongo {

     thread_local bson thread_bson;
     thread_local mongo thread_mongo;

    static int encode(lua_State* L) {
        return thread_bson.encode(L);
    }
    static int decode(lua_State* L, const char* buf, size_t len) {
        return thread_bson.decode(L, buf, len);
    }
    static slice* encode_slice(lua_State* L) {
        return thread_bson.encode_slice(L);
    }
    static int decode_slice(lua_State* L, slice* buf) {
        return thread_bson.decode_slice(L, buf);
    }
    static int encode_order(lua_State* L) {
        return thread_bson.encode_order(L);
    }    
    static bson_value* encode_sparse(lua_State* L) {
        return thread_bson.encode_sparse(L);
    }
    static slice* encode_order_slice(lua_State* L) {
        return thread_bson.encode_order_slice(L);
    }
    static int reply(lua_State* L, const char* buf, size_t len) {
        return thread_mongo.reply(L, buf, len);
    }    
    static int reply_slice(lua_State* L, slice* buf) {
        return thread_mongo.reply_slice(L, buf);
    }    
    static int op_msg(lua_State* L) {
        return thread_mongo.op_msg(L);
    }
    static slice* op_msg_slice(lua_State* L, slice* buf, uint32_t id, uint32_t flags) {
        return thread_mongo.op_msg_slice(L, buf, id, flags);
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

    static void init_static_mongo() {
        for (int i = 0; i < max_bson_index; ++i) {
            char tmp[8];
            bson_numstr_len[i] = sprintf(tmp, "%d", i);
            memcpy(bson_numstrs[i], tmp, bson_numstr_len[i]);
        }
    }

    luakit::lua_table open_lmongo(lua_State* L) {
        luakit::kit_state kit_state(L);
        auto llmongo = kit_state.new_table();
        llmongo.set_function("reply", reply);
        llmongo.set_function("opmsg", op_msg);
        llmongo.set_function("encode", encode);
        llmongo.set_function("decode", decode);
        llmongo.set_function("reply_slice", reply_slice);
        llmongo.set_function("opmsg_slice", op_msg_slice);
        llmongo.set_function("encode_slice", encode_slice);
        llmongo.set_function("decode_slice", decode_slice);
        llmongo.set_function("encode_order", encode_order);
        llmongo.set_function("encode_sparse", encode_sparse);
        llmongo.set_function("encode_order_slice", encode_order_slice);
        llmongo.set_function("timestamp", timestamp);
        llmongo.set_function("int32", int32);
        llmongo.set_function("int64", int64);
        llmongo.set_function("date", date);
        kit_state.new_class<bson_value>(
            "val", &bson_value::val,
            "str", &bson_value::str,
            "type", &bson_value::type,
            "stype", &bson_value::stype
            );
        return llmongo;
    }
}

extern "C" {
    LUALIB_API int luaopen_lmongo(lua_State* L) {
        lmongo::init_static_mongo();
        auto lluabus = lmongo::open_lmongo(L);
        return lluabus.push_stack();
    }
}
