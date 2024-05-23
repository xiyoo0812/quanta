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

    static codec_base* httpd_codec(codec_base* codec, bool jsondecode) {
        httpcodec* hcodec = new httpdcodec();
        hcodec->set_codec(codec);
        hcodec->set_buff(&thread_buff);
        hcodec->set_jsondecode(jsondecode);
        return hcodec;
    }

    static codec_base* httpc_codec(codec_base* codec, bool jsondecode) {
        httpcodec* hcodec = new httpccodec();
        hcodec->set_codec(codec);
        hcodec->set_buff(&thread_buff);
        hcodec->set_jsondecode(jsondecode);
        return hcodec;
    }

    static codec_base* mysql_codec(size_t session_id) {
        mysqlscodec* codec = new mysqlscodec(session_id);
        codec->set_buff(&thread_buff);
        return codec;
    }

    luakit::lua_table open_lcodec(lua_State* L) {
        luakit::kit_state kit_state(L);
        auto llcodec = kit_state.new_table("codec");
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
        llcodec.set_function("httpccodec", httpc_codec);
        llcodec.set_function("httpdcodec", httpd_codec);
        llcodec.set_function("mysqlcodec", mysql_codec);
        llcodec.set_function("rediscodec", rds_codec);
        llcodec.set_function("wsscodec", wss_codec);
        llcodec.set_function("url_encode", url_encode);
        llcodec.set_function("url_decode", url_decode);
        llcodec.set_function("bit32_new", lua_bitset_new<32>);
        llcodec.set_function("bit64_new", lua_bitset_new<64>);
        llcodec.set_function("bit128_new", lua_bitset_new<128>);
        llcodec.set_function("bit256_new", lua_bitset_new<256>);
        llcodec.set_function("bit512_new", lua_bitset_new<512>);
        llcodec.set_function("bit32_get", lua_bitset_get<32>);
        llcodec.set_function("bit64_get", lua_bitset_get<64>);
        llcodec.set_function("bit128_get", lua_bitset_get<128>);
        llcodec.set_function("bit256_get", lua_bitset_get<256>);
        llcodec.set_function("bit512_get", lua_bitset_get<512>);
        llcodec.set_function("bit32_set", lua_bitset_set<32>);
        llcodec.set_function("bit64_set", lua_bitset_set<64>);
        llcodec.set_function("bit128_set", lua_bitset_set<128>);
        llcodec.set_function("bit256_set", lua_bitset_set<256>);
        llcodec.set_function("bit512_set", lua_bitset_set<512>);
        llcodec.set_function("bit32_flip", lua_bitset_flip<32>);
        llcodec.set_function("bit64_flip", lua_bitset_flip<64>);
        llcodec.set_function("bit128_flip", lua_bitset_flip<128>);
        llcodec.set_function("bit256_flip", lua_bitset_flip<256>);
        llcodec.set_function("bit512_flip", lua_bitset_flip<512>);
        llcodec.set_function("bit32_reset", lua_bitset_reset<32>);
        llcodec.set_function("bit64_reset", lua_bitset_reset<64>);
        llcodec.set_function("bit128_reset", lua_bitset_reset<128>);
        llcodec.set_function("bit256_reset", lua_bitset_reset<256>);
        llcodec.set_function("bit512_reset", lua_bitset_reset<512>);
        llcodec.set_function("bit32_check", lua_bitset_check<32>);
        llcodec.set_function("bit64_check", lua_bitset_check<64>);
        llcodec.set_function("bit128_check", lua_bitset_check<128>);
        llcodec.set_function("bit256_check", lua_bitset_check<256>);
        llcodec.set_function("bit512_check", lua_bitset_check<512>);
        return llcodec;
    }
}

extern "C" {
    LUALIB_API int luaopen_lcodec(lua_State* L) {
        auto llcodec = lcodec::open_lcodec(L);
        return llcodec.push_stack();
    }
}
