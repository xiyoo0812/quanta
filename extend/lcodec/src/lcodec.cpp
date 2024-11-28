#define LUA_LIB

#include "lcodec.h"

namespace lcodec {

    static codec_base* rds_codec(codec_base* codec) {
        rdscodec* rcodec = new rdscodec();
        rcodec->set_codec(codec);
        rcodec->set_buff(luakit::get_buff());
        return rcodec;
    }

    static codec_base* wss_codec(codec_base* codec) {
        wsscodec* wcodec = new wsscodec();
        wcodec->set_codec(codec);
        wcodec->set_buff(luakit::get_buff());
        return wcodec;
    }

    static bitset* bitset_new() {
        return new bitset();
    }

    static codec_base* httpd_codec(codec_base* codec) {
        httpcodec* hcodec = new httpdcodec();
        hcodec->set_codec(codec);
        hcodec->set_buff(luakit::get_buff());
        return hcodec;
    }

    static codec_base* httpc_codec(codec_base* codec) {
        httpcodec* hcodec = new httpccodec();
        hcodec->set_codec(codec);
        hcodec->set_buff(luakit::get_buff());
        return hcodec;
    }

    static codec_base* mysql_codec(size_t session_id) {
        mysqlscodec* codec = new mysqlscodec(session_id);
        codec->set_buff(luakit::get_buff());
        return codec;
    }

    static codec_base* pgsql_codec() {
        pgsqlscodec* codec = new pgsqlscodec();
        codec->set_buff(luakit::get_buff());
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
        llcodec.set_function("pgsqlcodec", pgsql_codec);
        llcodec.set_function("rediscodec", rds_codec);
        llcodec.set_function("wsscodec", wss_codec);
        llcodec.set_function("url_encode", url_encode);
        llcodec.set_function("url_decode", url_decode);
        llcodec.set_function("bitset", bitset_new);
        llcodec.new_enum("pgsql_type_f",
            "bind", cmd_type_f::bind,
            "sync", cmd_type_f::sync,
            "close", cmd_type_f::close,
            "query", cmd_type_f::query,
            "parse", cmd_type_f::parse,
            "flush", cmd_type_f::flush,
            "execute", cmd_type_f::execute,
            "discribe", cmd_type_f::discribe,
            "password", cmd_type_f::password,
            "function_call", cmd_type_f::function_call,
            "startup", cmd_type_f::startup
        );
        llcodec.new_enum("auth_type_t",
            "ok", auth_type_t::ok,
            "v5", auth_type_t::v5,
            "md5", auth_type_t::md5,
            "scm", auth_type_t::scm,
            "gss", auth_type_t::gss,
            "sspi", auth_type_t::sspi,
            "sasl", auth_type_t::sasl,
            "cleartext", auth_type_t::cleartext,
            "sasl_final", auth_type_t::sasl_final,
            "gss_continue", auth_type_t::gss_continue,
            "sasl_continue", auth_type_t::sasl_continue
        );
        kit_state.new_class<bitset>(
            "get", &bitset::get,
            "set", &bitset::set,
            "hex", &bitset::hex,
            "load", &bitset::load,
            "flip", &bitset::flip,
            "reset", &bitset::reset,
            "check", &bitset::check,
            "binary", &bitset::binary,
            "loadhex", &bitset::loadhex,
            "loadbin", &bitset::loadbin,
            "tostring", &bitset::tostring
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
