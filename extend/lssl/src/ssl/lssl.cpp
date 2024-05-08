#define LUA_LIB
#include "ssl/crc.h"
#include "ssl/lz4.h"
#include "ssl/xxtea.h"
#include "ssl/hmac_sha.h"

#include "lssl.h"

#define HEX(v,c) { char tmp = (char) c; if (tmp >= '0' && tmp <= '9') { v = tmp-'0'; } else { v = tmp - 'a' + 10; } }

namespace lssl {
    thread_local luakit::luabuf thread_buff;

    static void hash(const char* str, int sz, char key[8]) {
        long djb_hash = 5381L;
        long js_hash = 1315423911L;
        int i;
        for (i = 0; i < sz; i++) {
            char c = (char)str[i];
            djb_hash += (djb_hash << 5) + c;
            js_hash ^= ((js_hash << 5) + c + (js_hash >> 2));
        }

        key[0] = djb_hash & 0xff;
        key[1] = (djb_hash >> 8) & 0xff;
        key[2] = (djb_hash >> 16) & 0xff;
        key[3] = (djb_hash >> 24) & 0xff;

        key[4] = js_hash & 0xff;
        key[5] = (js_hash >> 8) & 0xff;
        key[6] = (js_hash >> 16) & 0xff;
        key[7] = (js_hash >> 24) & 0xff;
    }

    static int lhashkey(lua_State* L) {
        size_t sz = 0;
        const char* key = luaL_checklstring(L, 1, &sz);
        char realkey[8];
        hash(key, (int)sz, realkey);
        lua_pushlstring(L, (const char*)realkey, 8);
        return 1;
    }

    static int tohex(lua_State* L, const unsigned char* text, size_t sz)
    {
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
        lua_pushlstring(L, buffer, sz * 2);
        return 1;
    }

    static int ltohex(lua_State* L) {
        size_t sz = 0;
        const unsigned char* text = (const unsigned char*)luaL_checklstring(L, 1, &sz);
        return tohex(L, text, sz);
    }

    static int lrandomkey(lua_State* L) {
        char tmp[8];
        int i;
        for (i = 0; i < 8; i++) {
            tmp[i] = rand() & 0xff;
        }
        if (luaL_optinteger(L, 1, 0)) {
            return tohex(L, (const unsigned char*)tmp, 8);
        }
        lua_pushlstring(L, tmp, 8);
        return 1;
    }

    static int lfromhex(lua_State* L) {
        size_t sz = 0;
        const unsigned char* text = (const unsigned char*)luaL_checklstring(L, 1, &sz);
        if (sz & 2) {
            return luaL_error(L, "Invalid hex text size %lu", (int)sz);
        }
        char tmp[UCHAR_MAX];
        char* buffer = tmp;
        if (sz > UCHAR_MAX * 2) {
            buffer = (char*)lua_newuserdata(L, sz / 2);
        }
        size_t i;
        for (i = 0; i < sz; i += 2) {
            char hi, low;
            HEX(hi, text[i]);
            HEX(low, text[i + 1]);
            if (hi > 16 || low > 16) {
                return luaL_error(L, "Invalid hex text", text);
            }
            buffer[i / 2] = hi << 4 | low;
        }
        lua_pushlstring(L, buffer, i / 2);
        return 1;
    }

    static int lxxtea_encode(lua_State* L) {
        size_t data_len = 0;
        size_t encode_len = 0;
        const char* key = luaL_checkstring(L, 1);
        const char* message = luaL_checklstring(L, 2, &data_len);
        char* encode_out = (char*)xxtea_encrypt(message, data_len, key, &encode_len);
        lua_pushlstring(L, encode_out, encode_len);
        free(encode_out);
        return 1;
    }

    static int lxxtea_decode(lua_State* L) {
        size_t data_len = 0;
        size_t decode_len = 0;
        const char* key = luaL_checkstring(L, 1);
        const char* message = luaL_checklstring(L, 2, &data_len);
        char* decode_out = (char*)xxtea_decrypt(message, data_len, key, &decode_len);
        lua_pushlstring(L, decode_out, decode_len);
        free(decode_out);
        return 1;
    }

    static int lbase64_encode(lua_State* L) {
        size_t data_len = 0;
        const char* input = luaL_checklstring(L, 1, &data_len);
        uint32_t out_len = BASE64_ENCODE_OUT_SIZE(data_len);
        unsigned char* output = (unsigned char*)malloc(out_len);
        Base64_Encode_NoNl((unsigned char*)input, data_len, output, &out_len);
        lua_pushlstring(L, (const char*)output, out_len);
        free(output);
        return 1;
    }

    static int lbase64_decode(lua_State* L) {
        size_t data_len = 0;
        const char* input = luaL_checklstring(L, 1, &data_len);
        uint32_t out_len = BASE64_DECODE_OUT_SIZE(data_len);
        unsigned char* output = (unsigned char*)malloc(out_len);
        Base64_Decode((const unsigned char*)input, data_len, output, &out_len);
        lua_pushlstring(L, (const char*)output, out_len);
        free(output);
        return 1;
    }

    static int lmd5(lua_State* L) {
        size_t data_len = 0;
        const unsigned char* message = (const unsigned char*)luaL_checklstring(L, 1, &data_len);
        unsigned char output[WC_MD5_DIGEST_SIZE];
        MD5(message, data_len, output);
        if (luaL_optinteger(L, 2, 0)) {
            return tohex(L, output, WC_MD5_DIGEST_SIZE);
        }
        lua_pushlstring(L, (const char*)output, WC_MD5_DIGEST_SIZE);
        return 1;
    }

    static int lz4_encode(lua_State* L) {
        size_t data_len = 0;
        char dest[USHRT_MAX];
        const char* message = luaL_checklstring(L, 1, &data_len);
        int out_len = LZ4_compress_default(message, dest, data_len, USHRT_MAX);
        if (out_len > 0) {
            lua_pushlstring(L, dest, out_len);
            return 1;
        }
        lua_pushstring(L, "lz4 compress failed!");
        lua_error(L);
        return 1;
    }

    static int lz4_decode(lua_State* L) {
        size_t data_len = 0;
        char dest[USHRT_MAX];
        const char* message = luaL_checklstring(L, 1, &data_len);
        int out_len = LZ4_decompress_safe(message, dest, data_len, USHRT_MAX);
        if (out_len > 0) {
            lua_pushlstring(L, dest, out_len);
            return 1;
        }
        lua_pushstring(L, "lz4 decompress failed!");
        lua_error(L);
        return 1;
    }

    static int lsha1(lua_State* L) {
        size_t sz = 0;
        uint8_t digest[WC_SHA_DIGEST_SIZE];
        const uint8_t* buffer = (const uint8_t*)luaL_checklstring(L, 1, &sz);
        SHA1(buffer, sz, digest);
        lua_pushlstring(L, (const char*)digest, WC_SHA_DIGEST_SIZE);
        return 1;
    }

    static int lsha224(lua_State* L) {
        size_t sz = 0;
        uint8_t digest[WC_SHA224_DIGEST_SIZE];
        const uint8_t* buffer = (const uint8_t*)luaL_checklstring(L, 1, &sz);
        SHA224(buffer, sz, digest);
        lua_pushlstring(L, (const char*)digest, WC_SHA224_DIGEST_SIZE);
        return 1;
    }

    static int lsha256(lua_State* L) {
        size_t sz = 0;
        uint8_t digest[WC_SHA256_DIGEST_SIZE];
        const uint8_t* buffer = (const uint8_t*)luaL_checklstring(L, 1, &sz);
        SHA256(buffer, sz, digest);
        lua_pushlstring(L, (const char*)digest, WC_SHA256_DIGEST_SIZE);
        return 1;
    }

    static int lsha384(lua_State* L) {
        size_t sz = 0;
        uint8_t digest[WC_SHA384_DIGEST_SIZE];
        const uint8_t* buffer = (const uint8_t*)luaL_checklstring(L, 1, &sz);
        SHA384(buffer, sz, digest);
        lua_pushlstring(L, (const char*)digest, WC_SHA384_DIGEST_SIZE);
        return 1;
    }

    static int lsha512(lua_State* L) {
        size_t sz = 0;
        uint8_t digest[WC_SHA512_DIGEST_SIZE];
        const uint8_t* buffer = (const uint8_t*)luaL_checklstring(L, 1, &sz);
        SHA512(buffer, sz, digest);
        lua_pushlstring(L, (const char*)digest, WC_SHA512_DIGEST_SIZE);
        return 1;
    }

    static int lhmac_sha1(lua_State* L) {
        size_t key_sz = 0, text_sz = 0;
        uint8_t digest[WC_SHA_DIGEST_SIZE];
        const uint8_t* key = (const uint8_t*)luaL_checklstring(L, 1, &key_sz);
        const uint8_t* text = (const uint8_t*)luaL_checklstring(L, 2, &text_sz);
        hmac_sha1(key, key_sz, text, text_sz, digest);
        lua_pushlstring(L, (const char*)digest, WC_SHA_DIGEST_SIZE);
        return 1;
    }

    static int lhmac_sha224(lua_State* L) {
        size_t key_sz = 0, text_sz = 0;
        uint8_t digest[WC_SHA224_DIGEST_SIZE];
        const uint8_t* key = (const uint8_t*)luaL_checklstring(L, 1, &key_sz);
        const uint8_t* text = (const uint8_t*)luaL_checklstring(L, 2, &text_sz);
        hmac_sha224(key, key_sz, text, text_sz, digest);
        lua_pushlstring(L, (const char*)digest, WC_SHA224_DIGEST_SIZE);
        return 1;
    }

    static int lhmac_sha256(lua_State* L) {
        size_t key_sz = 0, text_sz = 0;
        uint8_t digest[WC_SHA256_DIGEST_SIZE];
        const uint8_t* key = (const uint8_t*)luaL_checklstring(L, 1, &key_sz);
        const uint8_t* text = (const uint8_t*)luaL_checklstring(L, 2, &text_sz);
        hmac_sha256(key, key_sz, text, text_sz, digest);
        lua_pushlstring(L, (const char*)digest, WC_SHA256_DIGEST_SIZE);
        return 1;
    }

    static int lhmac_sha384(lua_State* L) {
        size_t key_sz = 0, text_sz = 0;
        uint8_t digest[WC_SHA384_DIGEST_SIZE];
        const uint8_t* key = (const uint8_t*)luaL_checklstring(L, 1, &key_sz);
        const uint8_t* text = (const uint8_t*)luaL_checklstring(L, 2, &text_sz);
        hmac_sha384(key, key_sz, text, text_sz, digest);
        lua_pushlstring(L, (const char*)digest, WC_SHA384_DIGEST_SIZE);
        return 1;
    }

    static int lhmac_sha512(lua_State* L) {
        size_t key_sz = 0, text_sz = 0;
        uint8_t digest[WC_SHA512_DIGEST_SIZE];
        const uint8_t* key = (const uint8_t*)luaL_checklstring(L, 1, &key_sz);
        const uint8_t* text = (const uint8_t*)luaL_checklstring(L, 2, &text_sz);
        hmac_sha512(key, key_sz, text, text_sz, digest);
        lua_pushlstring(L, (const char*)digest, WC_SHA512_DIGEST_SIZE);
        return 1;
    }

    static int lxor_byte(lua_State* L) {
        size_t len1, len2;
        const char* s1 = luaL_checklstring(L, 1, &len1);
        const char* s2 = luaL_checklstring(L, 2, &len2);
        if (len2 == 0) {
            return luaL_error(L, "Can't xor empty string");
        }
        luaL_Buffer b;
        char* buffer = luaL_buffinitsize(L, &b, len1);
        size_t i;
        for (i = 0; i < len1; i++) {
            buffer[i] = s1[i] ^ s2[i % len2];
        }
        luaL_addsize(&b, len1);
        luaL_pushresult(&b);
        return 1;
    }

    static lua_rsa_key* lrsa_init_pubkey(std::string_view pem_key) {
        lua_rsa_key* key = new lua_rsa_key();
        if (!key->init_pubkey(pem_key)) {
            delete key;
            key = nullptr;
        }
        return key;
    }

    static lua_rsa_key* lrsa_init_prikey(std::string_view pem_key) {
        lua_rsa_key* key = new lua_rsa_key();
        if (!key->init_prikey(pem_key)) {
            delete key;
            key = nullptr;
        }
        return key;
    }

    static int lcrc8(lua_State* L) {
        size_t len;
        const char* key = lua_tolstring(L, 1, &len);
        lua_pushinteger(L, crc8_lsb(key, len));
        return 1;
    }

    static int lcrc8_msb(lua_State* L) {
        size_t len;
        const char* key = lua_tolstring(L, 1, &len);
        lua_pushinteger(L, crc8_msb(key, len));
        return 1;
    }

    static int lcrc16(lua_State* L) {
        size_t len;
        const char* key = lua_tolstring(L, 1, &len);
        lua_pushinteger(L, crc16(key, len));
        return 1;
    }

    static int lcrc32(lua_State* L) {
        size_t len;
        const char* key = lua_tolstring(L, 1, &len);
        lua_pushinteger(L, crc32(key, len));
        return 1;
    }

    static int lcrc64(lua_State* L) {
        size_t len;
        const char* key = lua_tolstring(L, 1, &len);
        lua_pushinteger(L, (int64_t)crc64(key, len));
        return 1;
    }

    static tlscodec* tls_codec(codec_base* codec) {
        tlscodec* tcodec = new tlscodec();
        tcodec->set_codec(codec);
        tcodec->set_buff(&thread_buff);
        return tcodec;
    }

    luakit::lua_table open_lssl(lua_State* L) {
        luakit::kit_state kit_state(L);
        auto luassl = kit_state.new_table("ssl");
        luassl.set_function("md5", lmd5);
        luassl.set_function("crc8", lcrc8);
        luassl.set_function("crc64", lcrc64);
        luassl.set_function("crc32", lcrc32);
        luassl.set_function("crc16", lcrc16);
        luassl.set_function("crc8_msb", lcrc8_msb);
        luassl.set_function("sha1", lsha1);
        luassl.set_function("sha224", lsha224);
        luassl.set_function("sha256", lsha256);
        luassl.set_function("sha384", lsha384);
        luassl.set_function("sha512", lsha512);
        luassl.set_function("hashkey", lhashkey);
        luassl.set_function("xor_byte", lxor_byte);
        luassl.set_function("hex_encode", ltohex);
        luassl.set_function("hex_decode", lfromhex);
        luassl.set_function("randomkey", lrandomkey);
        luassl.set_function("lz4_encode", lz4_encode);
        luassl.set_function("lz4_decode", lz4_decode);
        luassl.set_function("hmac_sha1", lhmac_sha1);
        luassl.set_function("hmac_sha224", lhmac_sha224);
        luassl.set_function("hmac_sha256", lhmac_sha256);
        luassl.set_function("hmac_sha384", lhmac_sha384);
        luassl.set_function("hmac_sha512", lhmac_sha512);
        luassl.set_function("b64_encode", lbase64_encode);
        luassl.set_function("b64_decode", lbase64_decode);
        luassl.set_function("xxtea_encode", lxxtea_encode);
        luassl.set_function("xxtea_decode", lxxtea_decode);
        luassl.set_function("rsa_init_pubkey", lrsa_init_pubkey);
        luassl.set_function("rsa_init_prikey", lrsa_init_prikey);
        luassl.set_function("tlscodec", tls_codec);
        kit_state.new_class<lua_rsa_key>(
            "pub_encode", &lua_rsa_key::pub_encode,
            "pub_decode", &lua_rsa_key::pub_decode,
            "pri_encode", &lua_rsa_key::pri_encode,
            "pri_decode", &lua_rsa_key::pri_decode
        );
        kit_state.new_class<tlscodec>(
            "init_tls", &tlscodec::init_tls,
            "set_cert", &tlscodec::set_cert,
            "isfinish", &tlscodec::isfinish,
            "set_ciphers", &tlscodec::set_ciphers
        );
        return luassl;
    }
}

extern "C" {
    static bool SSL_IS_INIT = false;
    LUALIB_API int luaopen_lssl(lua_State* L) {
        if (!SSL_IS_INIT) {
            SSL_IS_INIT = true;
            SSL_library_init();
            OpenSSL_add_all_algorithms();
        }
        auto luassl = lssl::open_lssl(L);
        return luassl.push_stack();
    }
}

