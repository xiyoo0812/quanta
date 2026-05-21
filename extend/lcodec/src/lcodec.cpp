#define LUA_LIB

#include "lcodec.h"

namespace lcodec {

    static uint8_t* alloc_buff(size_t sz) {
        auto buf = get_buff();
        return buf->peek_space(sz);
    }

    static codec_base* rds_codec(codec_base* codec) {
        rdscodec* rcodec = new rdscodec();
        rcodec->set_codec(codec);
        rcodec->set_buff(get_buff());
        return rcodec;
    }

    static codec_base* wss_codec(codec_base* codec, bool mask) {
        wsscodec* wcodec = new wsscodec();
        wcodec->set_codec(codec);
        wcodec->set_buff(get_buff());
        if (mask) wcodec->build_mask();
        return wcodec;
    }

    static bitset* bitset_new() {
        return new bitset();
    }

    static codec_base* httpd_codec() {
        httpcodec* hcodec = new httpdcodec();
        hcodec->set_buff(get_buff());
        return hcodec;
    }

    static codec_base* httpc_codec() {
        httpcodec* hcodec = new httpccodec();
        hcodec->set_buff(get_buff());
        return hcodec;
    }

    static codec_base* http2c_codec() {
        auto hcodec = new http2codec<h2c_stream>();
        hcodec->set_buff(get_buff());
        return hcodec;
    }

    static codec_base* grpcc_codec() {
        auto hcodec = new http2codec<grpcc_stream>();
        hcodec->set_buff(get_buff());
        return hcodec;
    }

    static codec_base* http2d_codec() {
        auto hcodec = new http2codec<h2d_stream>();
        hcodec->set_buff(get_buff());
        return hcodec;
    }

    static void set_content_codec(codec_base* base, string_view type, codec_base* content_type, codec_base* content_encoding) {
        http_codec_base* hcodec = dynamic_cast<http_codec_base*>(base);
        if (hcodec){
            hcodec->set_content_encoding_codec(content_encoding);
            hcodec->set_content_type_codec(type, content_type);
        }
    }

    static codec_base* mysql_codec(size_t session_id) {
        mysqlscodec* codec = new mysqlscodec(session_id);
        codec->set_buff(get_buff());
        return codec;
    }

    static codec_base* pgsql_codec() {
        pgsqlscodec* codec = new pgsqlscodec();
        codec->set_buff(get_buff());
        return codec;
    }

    static int tohex(lua_State* L, upchar text, size_t sz, int index) {
        static char hex[] = "0123456789abcdef";
        char tmp[UCHAR_MAX];
        char* buffer = tmp;
        if (sz > UCHAR_MAX / 2) {
            buffer = (char*)lua_newuserdata(L, sz * 2);
        }
        for (size_t i = 0; i < sz; i++) {
            buffer[i * 2] = hex[text[i] >> 4];
            buffer[i * 2 + 1] = hex[text[i] & 0xf];
        }
        push_string(L, (cpchar)buffer, sz * 2, index);
        return 1;
    }

    static int ltohex(lua_State* L) {
        size_t sz = 0;
        upchar text = (upchar)luaL_tolstring(L, 1, &sz);
        return tohex(L, text, sz, 2);
    }

    static int lrandomkey(lua_State* L) {
        int size = luaL_optinteger(L, 1, 12);
        auto tmp = alloc_buff(size);
        for (int i = 0; i < size; i++) {
            tmp[i] = rand() & 0xff;
        }
        if (lua_toboolean(L, 2)) {
            return tohex(L, (upchar)tmp, size, 3);
        }
        push_string(L, (cpchar)tmp, size, 3);
        return 1;
    }

    static int lfromhex(lua_State* L) {
        size_t sz = 0;
        upchar text = (upchar)luaL_checklstring(L, 1, &sz);
        if (sz & 2) {
            return luaL_error(L, "Invalid hex text size %lu", (int)sz);
        }
        size_t len = sz / 2;
        auto buffer = alloc_buff(len);
        for (size_t i = 0; i < sz; i += 2) {
            char hi = fromhex(text[i]);
            char low = fromhex(text[i + 1]);
            if (hi > 16 || low > 16) {
                return luaL_error(L, "Invalid hex text: %s", text);
            }
            buffer[i / 2] = hi << 4 | low;
        }
        push_string(L, (cpchar)buffer, len, 2);
        return 1;
    }

    static int lxor_byte(lua_State* L) {
        size_t len1, len2;
        cpchar s1 = luaL_checklstring(L, 1, &len1);
        cpchar s2 = luaL_checklstring(L, 2, &len2);
        if (len2 < len1) {
            return luaL_error(L, "Can't xor short src string");
        }
        auto buffer = alloc_buff(len1);
        for (size_t i = 0; i < len1; i++) {
            buffer[i] = s1[i] ^ s2[i];
        }
        push_string(L, (cpchar)buffer, len1, 3);
        return 1;
    }

    luakit::lua_table open_lcodec(lua_State* L) {
        luakit::kit_state kit_state(L);
        auto llcodec = kit_state.new_table("codec");
        llcodec.set_function("guid_new", guid_new);
        llcodec.set_function("guid_hex", guid_hex);
        llcodec.set_function("guid_tohex", guid_tohex);
        llcodec.set_function("guid_tobin", guid_tobin);
        llcodec.set_function("guid_string", guid_string);
        llcodec.set_function("guid_totrace", guid_totrace);
        llcodec.set_function("guid_tostring", guid_tostring);
        llcodec.set_function("string_toguid", string_toguid);
        llcodec.set_function("hex_toguid", string_toguid);
        llcodec.set_function("guid_encode", guid_encode);
        llcodec.set_function("guid_decode", guid_decode);
        llcodec.set_function("guid_source", guid_source);
        llcodec.set_function("guid_group", guid_group);
        llcodec.set_function("guid_index", guid_index);
        llcodec.set_function("guid_time", guid_time);
        llcodec.set_function("hash_code", hash_code);
        llcodec.set_function("hashkey", lhashkey);
        llcodec.set_function("grpcccodec", grpcc_codec);
        llcodec.set_function("httpccodec", httpc_codec);
        llcodec.set_function("httpdcodec", httpd_codec);
        llcodec.set_function("http2ccodec", http2c_codec);
        llcodec.set_function("http2dcodec", http2d_codec);
        llcodec.set_function("mysqlcodec", mysql_codec);
        llcodec.set_function("pgsqlcodec", pgsql_codec);
        llcodec.set_function("rediscodec", rds_codec);
        llcodec.set_function("wsscodec", wss_codec);
        llcodec.set_function("url_encode", url_encode);
        llcodec.set_function("url_decode", url_decode);
        llcodec.set_function("set_content_codec", set_content_codec);
        llcodec.set_function("xor_byte", lxor_byte);
        llcodec.set_function("hex_encode", ltohex);
        llcodec.set_function("hex_decode", lfromhex);
        llcodec.set_function("randomkey", lrandomkey);
        llcodec.set_function("bitset", bitset_new);
        llcodec.new_enum("pgsql_type_f",
            "BIND", BIND,
            "SYNC", SYNC,
            "CLOSE", CLOSE,
            "QUERY", QUERY,
            "PARSE", PARSE,
            "FLUSH", FLUSH,
            "EXECUTE", EXECUTE,
            "DISCRIBE", DISCRIBE,
            "PASSWORD", PASSWORD,
            "FUNC_CALL", FUNC_CALL,
            "STARTUP", STARTUP
        );
        llcodec.new_enum("auth_type_t",
            "OK", OK,
            "V5", V5,
            "MD5", MD5,
            "SCM", SCM,
            "GSS", GSS,
            "SSPI", SSPI,
            "SASL", SASL,
            "CLEARTEXT", CLEARTEXT,
            "SASL_FINAL", SASL_FINAL,
            "GSS_CONTINUE", GSS_CONTINUE,
            "SASL_CONTINUE", SASL_CONTINUE
        );
        llcodec.new_enum("h2_frame_type",
            "DATA", H2_DATA,
            "PING", H2_PING,
            "HEADES", H2_HEADES,
            "GOAWAY", H2_GOAWAY,
            "PRIORITY", H2_PRIORITY,
            "SETTINGS", H2_SETTINGS,
            "RST_STREAM", H2_RST_STREAM,
            "PUSH_PROMISE", H2_PUSH_PROMISE,
            "CONTINUATION", H2_CONTINUATION,
            "WINDOW_UPDATE", H2_WINDOW_UPDATE
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
        lcodec::init_huffman_tree();
        lcodec::init_static_headers(lcodec::get_buff());
        auto llcodec = lcodec::open_lcodec(L);
        return llcodec.push_stack();
    }
}
