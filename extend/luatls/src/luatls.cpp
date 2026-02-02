#define LUA_LIB
#include "extend/crc.h"
#include "extend/xxtea.h"

#include "luatls.h"

namespace luatls {

    static uint8_t* alloc_buff(size_t sz) {
        auto buf = luakit::get_buff();
        return buf->peek_space(sz);
    }
    
    static int tohex(lua_State* L, const unsigned char* text, size_t sz) {
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

    static int lxxtea_encode(lua_State* L) {
        size_t data_len = 0;
        size_t encode_len = 0;
        cpchar key = luaL_checkstring(L, 1);
        cpchar message = luaL_checklstring(L, 2, &data_len);
        char* encode_out = (char*)xxtea_encrypt(message, data_len, key, &encode_len);
        lua_pushlstring(L, encode_out, encode_len);
        free(encode_out);
        return 1;
    }

    static int lxxtea_decode(lua_State* L) {
        size_t data_len = 0;
        size_t decode_len = 0;
        cpchar key = luaL_checkstring(L, 1);
        cpchar message = luaL_checklstring(L, 2, &data_len);
        char* decode_out = (char*)xxtea_decrypt(message, data_len, key, &decode_len);
        lua_pushlstring(L, decode_out, decode_len);
        free(decode_out);
        return 1;
    }

    static int lbase64_encode(lua_State* L) {
        size_t data_len = 0;
        cpchar input = luaL_checklstring(L, 1, &data_len);
        size_t out_len = BASE64_ENCODE_OUT_SIZE(data_len);
        unsigned char* output = alloc_buff(out_len);
        mbedtls_base64_encode(output, out_len, &out_len, (unsigned char*)input, data_len);
        lua_pushlstring(L, (cpchar)output, out_len);
        return 1;
    }

    static int lbase64_decode(lua_State* L) {
        size_t data_len = 0;
        cpchar input = luaL_checklstring(L, 1, &data_len);
        size_t out_len = BASE64_DECODE_OUT_SIZE(data_len);
        unsigned char* output = alloc_buff(out_len);
        mbedtls_base64_decode(output, out_len, &out_len, (const unsigned char*)input, data_len);
        lua_pushlstring(L, (cpchar)output, out_len);
        return 1;
    }

    static int lmd5(lua_State* L) {
        size_t data_len = 0;
        auto message = (const unsigned char*)luaL_checklstring(L, 1, &data_len);
        unsigned char output[MD5_DIGEST_SIZE];
        auto md_info = mbedtls_md_info_from_type(MBEDTLS_MD_MD5);
        mbedtls_md(md_info, message, data_len, output);
        if (lua_toboolean(L, 2)) {
            return tohex(L, output, MD5_DIGEST_SIZE);
        }
        lua_pushlstring(L, (cpchar)output, MD5_DIGEST_SIZE);
        return 1;
    }

    static int pbkdf2_sha1(lua_State* L) {
        size_t psz = 0, ssz = 0;
        uint8_t digest[SHA_DIGEST_SIZE];
        upchar passwd = (upchar)luaL_checklstring(L, 1, &psz);
        upchar salt = (upchar)luaL_checklstring(L, 2, &ssz);
        int iter = lua_tointeger(L, 3);
        mbedtls_pkcs5_pbkdf2_hmac_ext(MBEDTLS_MD_SHA1, passwd, psz, salt, ssz, iter, SHA_DIGEST_SIZE, digest);
        lua_pushlstring(L, (cpchar)digest, SHA_DIGEST_SIZE);
        return 1;
    }

    static int pbkdf2_sha256(lua_State* L) {
        size_t psz = 0, ssz = 0;
        uint8_t digest[SHA256_DIGEST_SIZE];
        upchar passwd = (upchar)luaL_checklstring(L, 1, &psz);
        upchar salt = (upchar)luaL_checklstring(L, 2, &ssz);
        int iter = lua_tointeger(L, 3);
        mbedtls_pkcs5_pbkdf2_hmac_ext(MBEDTLS_MD_SHA256, passwd, psz, salt, ssz, iter, SHA256_DIGEST_SIZE, digest);
        lua_pushlstring(L, (cpchar)digest, SHA256_DIGEST_SIZE);
        return 1;
    }

    static int lsha1(lua_State* L) {
        size_t sz = 0;
        uint8_t digest[SHA_DIGEST_SIZE];
        upchar buffer = (upchar)luaL_checklstring(L, 1, &sz);
        mbedtls_sha1(buffer, sz, digest);
        lua_pushlstring(L, (cpchar)digest, SHA_DIGEST_SIZE);
        return 1;
    }

    static int lsha256(lua_State* L) {
        size_t sz = 0;
        uint8_t digest[SHA256_DIGEST_SIZE];
        upchar buffer = (upchar)luaL_checklstring(L, 1, &sz);
        mbedtls_sha256(buffer, sz, digest, 0);
        lua_pushlstring(L, (cpchar)digest, SHA256_DIGEST_SIZE);
        return 1;
    }

    static int lsha512(lua_State* L) {
        size_t sz = 0;
        uint8_t digest[SHA512_DIGEST_SIZE];
        upchar buffer = (upchar)luaL_checklstring(L, 1, &sz);
        mbedtls_sha512(buffer, sz, digest, 0);
        lua_pushlstring(L, (cpchar)digest, SHA512_DIGEST_SIZE);
        return 1;
    }

    static int lhmac_sha1(lua_State* L) {
        size_t key_sz = 0, text_sz = 0;
        uint8_t digest[SHA_DIGEST_SIZE];
        const uint8_t* key = (const uint8_t*)luaL_checklstring(L, 1, &key_sz);
        const uint8_t* text = (const uint8_t*)luaL_checklstring(L, 2, &text_sz);
        auto md_info = mbedtls_md_info_from_type(MBEDTLS_MD_SHA1);
        mbedtls_md_hmac(md_info, key, key_sz, text, text_sz, digest);
        lua_pushlstring(L, (cpchar)digest, SHA_DIGEST_SIZE);
        return 1;
    }

    static int lhmac_sha256(lua_State* L) {
        size_t key_sz = 0, text_sz = 0;
        uint8_t digest[SHA256_DIGEST_SIZE];
        const uint8_t* key = (const uint8_t*)luaL_checklstring(L, 1, &key_sz);
        const uint8_t* text = (const uint8_t*)luaL_checklstring(L, 2, &text_sz);
        auto md_info = mbedtls_md_info_from_type(MBEDTLS_MD_SHA256);
        mbedtls_md_hmac(md_info, key, key_sz, text, text_sz, digest);
        lua_pushlstring(L, (cpchar)digest, SHA256_DIGEST_SIZE);
        return 1;
    }

    static int lhmac_sha512(lua_State* L) {
        size_t key_sz = 0, text_sz = 0;
        uint8_t digest[SHA512_DIGEST_SIZE];
        const uint8_t* key = (const uint8_t*)luaL_checklstring(L, 1, &key_sz);
        const uint8_t* text = (const uint8_t*)luaL_checklstring(L, 2, &text_sz);
        auto md_info = mbedtls_md_info_from_type(MBEDTLS_MD_SHA512);
        mbedtls_md_hmac(md_info, key, key_sz, text, text_sz, digest);
        lua_pushlstring(L, (cpchar)digest, SHA512_DIGEST_SIZE);
        return 1;
    }
    
    static lua_rsa_key* lrsa_key(std::string_view pem_key) {
        return new lua_rsa_key();
    }

    static int lcrc8(lua_State* L) {
        size_t len;
        cpchar key = lua_tolstring(L, 1, &len);
        lua_pushinteger(L, crc8_lsb(key, len));
        return 1;
    }

    static int lcrc8_msb(lua_State* L) {
        size_t len;
        cpchar key = lua_tolstring(L, 1, &len);
        lua_pushinteger(L, crc8_msb(key, len));
        return 1;
    }

    static int lcrc16(lua_State* L) {
        size_t len;
        cpchar key = lua_tolstring(L, 1, &len);
        lua_pushinteger(L, crc16(key, len));
        return 1;
    }

    static int lcrc32(lua_State* L) {
        size_t len;
        cpchar key = lua_tolstring(L, 1, &len);
        lua_pushinteger(L, crc32(key, len));
        return 1;
    }

    static int lcrc64(lua_State* L) {
        size_t len;
        cpchar key = lua_tolstring(L, 1, &len);
        lua_pushinteger(L, (int64_t)crc64(key, len));
        return 1;
    }

    static tlscodec* tls_codec(lua_State* L, char* hostname, char* protos) {
        tlscodec* tcodec = new tlscodec();
        tcodec->set_buff(luakit::get_buff());
        tcodec->init_tls(L, hostname, protos);
        return tcodec;
    }

    static int lclean(lua_State* L) {
        cleanup_mbedtls_globals();
        return 0;
    }

    static int init_cas(lua_State* L, std::string_view cafile) {
        if (int ret = mbedtls_x509_crt_parse_file(&TL_SSL_TRUSTED_CAS, cafile.data()); ret != 0) {
            luaL_error(L, "mbedtls_x509_crt_parse_file('%s') error", cafile.data());
        }
        mbedtls_ssl_conf_authmode(&TL_SSL_CLI_CONF, MBEDTLS_SSL_VERIFY_REQUIRED);
        mbedtls_ssl_conf_ca_chain(&TL_SSL_CLI_CONF, &TL_SSL_TRUSTED_CAS, nullptr);
        return 0;
    }

    static int init_cert(lua_State* L, std::string_view certfile, std::string_view keyfile) {
        if (int ret = mbedtls_x509_crt_parse_file(&TL_SSL_SRVCERT, certfile.data()); ret != 0) {
            luaL_error(L, "mbedtls_x509_crt_parse_file('%s') error", certfile.data());
        }
        if (int ret = mbedtls_pk_parse_keyfile(&TL_SSL_PKEY, keyfile.data(), nullptr, nullptr, nullptr); ret != 0) {
            luaL_error(L, "mbedtls_pk_parse_keyfile('%s') error", keyfile.data());
        }
        if (int ret = mbedtls_pk_check_pair(&TL_SSL_SRVCERT.pk, &TL_SSL_PKEY, nullptr, nullptr); ret != 0) {
            luaL_error(L, "certificate and private key do not match: %d", ret);
        }
        if (int ret = mbedtls_ssl_conf_own_cert(&TL_SSL_SER_CONF, &TL_SSL_SRVCERT, &TL_SSL_PKEY); ret != 01) {
            luaL_error(L, "mbedtls_ssl_conf_own_cer error: %d", ret);
        }
        return 0;
    }

    luakit::lua_table open_ltls(lua_State* L) {
        luakit::kit_state kit_state(L);
        auto luassl = kit_state.new_table("tls");
        luassl.set_function("md5", lmd5);
        luassl.set_function("crc8", lcrc8);
        luassl.set_function("crc64", lcrc64);
        luassl.set_function("crc32", lcrc32);
        luassl.set_function("crc16", lcrc16);
        luassl.set_function("crc8_msb", lcrc8_msb);
        luassl.set_function("sha1", lsha1);
        luassl.set_function("sha256", lsha256);
        luassl.set_function("sha512", lsha512);
        luassl.set_function("hmac_sha1", lhmac_sha1);
        luassl.set_function("hmac_sha256", lhmac_sha256);
        luassl.set_function("hmac_sha512", lhmac_sha512);
        luassl.set_function("pbkdf2_sha1", pbkdf2_sha1);
        luassl.set_function("pbkdf2_sha256", pbkdf2_sha256);
        luassl.set_function("b64_encode", lbase64_encode);
        luassl.set_function("b64_decode", lbase64_decode);
        luassl.set_function("xxtea_encode", lxxtea_encode);
        luassl.set_function("xxtea_decode", lxxtea_decode);
        luassl.set_function("init_cert", init_cert);
        luassl.set_function("init_cas", init_cas);
        luassl.set_function("tlscodec", tls_codec);
        luassl.set_function("rsa_key", lrsa_key);
        luassl.set_function("clean", lclean);
        
        kit_state.new_class<lua_rsa_key>(
            "set_pubkey", &lua_rsa_key::set_pubkey,
            "set_prikey", &lua_rsa_key::set_prikey,
            "encrypt", &lua_rsa_key::encrypt,
            "decrypt", &lua_rsa_key::decrypt,
            "verify", &lua_rsa_key::verify,
            "sign", &lua_rsa_key::sign
        );
        kit_state.new_class<tlscodec>(
            "isfinish", &tlscodec::isfinish,
            "set_codec", &tlscodec::set_codec
        );
        return luassl;
    }
}

extern "C" {
    LUALIB_API int luaopen_luatls(lua_State* L) {
        luatls::init_mbedtls_globals();
        auto luatls = luatls::open_ltls(L);
        return luatls.push_stack();
    }
}

