#define LUA_LIB

#include "lcodec.h"

namespace lcodec {

    thread_local luakit::luabuf thread_buff;

    static codec_base* rds_codec(codec_base* codec) {
        rdscodec* rcodec = new rdscodec();
        rcodec->set_codec(codec);
        rcodec->set_buff(&thread_buff);
        return rcodec;
    }

    static codec_base* wss_codec(codec_base* codec) {
        wsscodec* wcodec = new wsscodec();
        wcodec->set_codec(codec);
        wcodec->set_buff(&thread_buff);
        return wcodec;
    }

    static codec_base* http_codec(codec_base* codec) {
        httpcodec* hcodec = new httpcodec();
        hcodec->set_codec(codec);
        hcodec->set_buff(&thread_buff);
        return hcodec;
    }

    static codec_base* mysql_codec(size_t session_id) {
        mysqlscodec* codec = new mysqlscodec(session_id);
        codec->set_buff(&thread_buff);
        return codec;
    }
    
    static bitarray* lbarray(lua_State* L, size_t nbits) {
        bitarray* barray = new bitarray();
        if (!barray->general(nbits)) {
            delete barray;
            return nullptr;
        }
        return barray;
    }

    luakit::lua_table open_lcodec(lua_State* L) {
        luakit::kit_state kit_state(L);
        auto llcodec = kit_state.new_table();
        llcodec.set_function("bitarray", lbarray);
        llcodec.set_function("guid_new", guid_new);
        llcodec.set_function("guid_string", guid_string);
        llcodec.set_function("guid_tostring", guid_tostring);
        llcodec.set_function("guid_number", guid_number);
        llcodec.set_function("guid_encode", guid_encode);
        llcodec.set_function("guid_decode", guid_decode);
        llcodec.set_function("guid_source", guid_source);
        llcodec.set_function("guid_group", guid_group);
        llcodec.set_function("guid_index", guid_index);
        llcodec.set_function("guid_time", guid_time);
        llcodec.set_function("hash_code", hash_code);
        llcodec.set_function("jumphash", jumphash_l);
        llcodec.set_function("fnv_1_32", fnv_1_32_l);
        llcodec.set_function("fnv_1a_32", fnv_1a_32_l);
        llcodec.set_function("murmur3_32", murmur3_32_l);
        llcodec.set_function("mysqlcodec", mysql_codec);
        llcodec.set_function("rediscodec", rds_codec);
        llcodec.set_function("httpcodec", http_codec);
        llcodec.set_function("wsscodec", wss_codec);

        kit_state.new_class<bitarray>(
            "flip", &bitarray::flip,
            "fill", &bitarray::fill,
            "equal", &bitarray::equal,
            "clone", &bitarray::clone,
            "slice", &bitarray::slice,
            "concat", &bitarray::concat,
            "lshift", &bitarray::lshift,
            "rshift", &bitarray::rshift,
            "length", &bitarray::length,
            "resize", &bitarray::resize,
            "reverse", &bitarray::reverse,
            "set_bit", &bitarray::set_bit,
            "get_bit", &bitarray::get_bit,
            "flip_bit", &bitarray::flip_bit,
            "to_string", &bitarray::to_string,
            "from_string", &bitarray::from_string,
            "to_uint8", &bitarray::to_number<uint8_t>,
            "to_uint16", &bitarray::to_number<uint16_t>,
            "to_uint32", &bitarray::to_number<uint32_t>,
            "to_uint64", &bitarray::to_number<uint64_t>,
            "from_uint8", &bitarray::from_number<uint8_t>,
            "from_uint16", &bitarray::from_number<uint16_t>,
            "from_uint32", &bitarray::from_number<uint32_t>,
            "from_uint64", &bitarray::from_number<uint64_t>
        );
        return llcodec;
    }
}

extern "C" {
    LUALIB_API int luaopen_lcodec(lua_State* L) {
        auto llcodec = lcodec::open_lcodec(L);
        return llcodec.push_stack();
    }
}
