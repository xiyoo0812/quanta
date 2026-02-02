#pragma once
#include "mbedtls/pk.h"
#include "mbedtls/md.h"
#include "mbedtls/ssl.h"
#include "mbedtls/rsa.h"
#include "mbedtls/sha1.h"
#include "mbedtls/error.h"
#include "mbedtls/pkcs5.h"
#include "mbedtls/sha256.h"
#include "mbedtls/sha512.h"
#include "mbedtls/base64.h"
#include "mbedtls/entropy.h"
#include "mbedtls/ctr_drbg.h"
#include "mbedtls/x509_crt.h"

#include "lua_kit.h"

using namespace luakit;

#define MD5_DIGEST_SIZE             16
#define SHA_DIGEST_SIZE             20
#define SHA256_DIGEST_SIZE          32
#define SHA512_DIGEST_SIZE          64
#define RSA_BUF_SIZE                512

#define RSA_PADDING_LEN             11
#define SSL_TLS_READ_SIZE           1024
#define RSA_ENCODE_LEN(m)           (m) - RSA_PADDING_LEN
#define BASE64_DECODE_OUT_SIZE(s)   ((unsigned int)(((s) / 4) * 3))
#define BASE64_ENCODE_OUT_SIZE(s)   ((unsigned int)((((s) + 2) / 3) * 4 + 1))
#define RSA_DECODE_OUT_SIZE(s, m)   (((s) + (m) - 1) / (m)) * (RSA_ENCODE_LEN(m)) + 1
#define RSA_ENCODE_OUT_SIZE(s, m)   (((s) + (RSA_ENCODE_LEN(m)) - 1) / (RSA_ENCODE_LEN(m))) * (m) + 1

namespace luatls {
    thread_local mbedtls_pk_context TL_SSL_PKEY;
    thread_local mbedtls_x509_crt TL_SSL_SRVCERT;
    thread_local mbedtls_ssl_config TL_SSL_CLI_CONF;
    thread_local mbedtls_ssl_config TL_SSL_SER_CONF;
    thread_local mbedtls_x509_crt TL_SSL_TRUSTED_CAS;
    thread_local mbedtls_entropy_context TL_SSL_ENTROPY;
    thread_local mbedtls_ctr_drbg_context TL_SSL_CTR_DRBG;

    inline void init_mbedtls_globals() {
        cpchar pers = "LUATLS";
        mbedtls_pk_init(&TL_SSL_PKEY);
        mbedtls_entropy_init(&TL_SSL_ENTROPY);
        mbedtls_x509_crt_init(&TL_SSL_SRVCERT);
        mbedtls_ctr_drbg_init(&TL_SSL_CTR_DRBG);
        mbedtls_x509_crt_init(&TL_SSL_TRUSTED_CAS);
        mbedtls_ssl_config_defaults(&TL_SSL_CLI_CONF, MBEDTLS_SSL_IS_CLIENT, MBEDTLS_SSL_TRANSPORT_STREAM, MBEDTLS_SSL_PRESET_DEFAULT);
        mbedtls_ssl_config_defaults(&TL_SSL_SER_CONF, MBEDTLS_SSL_IS_SERVER, MBEDTLS_SSL_TRANSPORT_STREAM, MBEDTLS_SSL_PRESET_DEFAULT);
        mbedtls_ctr_drbg_seed(&TL_SSL_CTR_DRBG, mbedtls_entropy_func, &TL_SSL_ENTROPY, (upchar)pers, strlen(pers));
        mbedtls_ssl_conf_rng(&TL_SSL_CLI_CONF, mbedtls_ctr_drbg_random, &TL_SSL_CTR_DRBG);
        mbedtls_ssl_conf_rng(&TL_SSL_SER_CONF, mbedtls_ctr_drbg_random, &TL_SSL_CTR_DRBG);
        mbedtls_ssl_conf_authmode(&TL_SSL_CLI_CONF, MBEDTLS_SSL_VERIFY_OPTIONAL);
    }

    inline void cleanup_mbedtls_globals() {
        mbedtls_x509_crt_free(&TL_SSL_TRUSTED_CAS);
        mbedtls_ssl_config_free(&TL_SSL_CLI_CONF);
        mbedtls_ssl_config_free(&TL_SSL_SER_CONF);
        mbedtls_ctr_drbg_free(&TL_SSL_CTR_DRBG);
        mbedtls_x509_crt_free(&TL_SSL_SRVCERT);
        mbedtls_entropy_free(&TL_SSL_ENTROPY);
        mbedtls_pk_free(&TL_SSL_PKEY);
    }

    class lua_rsa_key {
    public:
        lua_rsa_key() {
            mbedtls_pk_init(&pk_pub);
            mbedtls_pk_init(&pk_pri);
        }

        ~lua_rsa_key() {
            mbedtls_pk_free(&pk_pub);
            mbedtls_pk_free(&pk_pri);
            rsa_sz = 0;
        }

        bool set_pubkey(std::string_view pkey) {
            int ret = mbedtls_pk_parse_public_key(&pk_pub, (upchar)pkey.data(), pkey.size());
            if (ret == 0 && mbedtls_pk_get_type(&pk_pub) == MBEDTLS_PK_RSA) {
                mbedtls_rsa_context* rsa = mbedtls_pk_rsa(pk_pub);
                rsa_sz = mbedtls_rsa_get_len(rsa);
                return true;
            }
            return false;

        }

        bool set_prikey(std::string_view pkey) {
            int ret = mbedtls_pk_parse_key(&pk_pri, (upchar)pkey.data(), pkey.size(), nullptr, 0, nullptr, nullptr);
            if (ret == 0 && mbedtls_pk_get_type(&pk_pri) == MBEDTLS_PK_RSA) {
                mbedtls_rsa_context* rsa = mbedtls_pk_rsa(pk_pri);
                rsa_sz = mbedtls_rsa_get_len(rsa);
                ret = mbedtls_pk_setup(&pk_pub, mbedtls_pk_info_from_type(MBEDTLS_PK_RSA));
                if (ret == 0) {
                    mbedtls_rsa_context* rsa_pub = mbedtls_pk_rsa(pk_pub);
                    mbedtls_rsa_copy(rsa_pub, rsa);
                }
                return true;
            }
            char buf[128];
            mbedtls_strerror(ret, buf, sizeof(buf));
            return false;
        }

        int encrypt(lua_State* L, std::string_view value) {
            if (mbedtls_pk_get_type(&pk_pub) != MBEDTLS_PK_RSA) {
                luaL_error(L, "rsa pubkey not initialized!");
            }
            luaL_Buffer b;
            uint8_t buf[RSA_BUF_SIZE];
            size_t value_sz = value.size();
            upchar value_p = (upchar)value.data();
            size_t out_size = RSA_ENCODE_OUT_SIZE(value_sz, rsa_sz);
            mbedtls_rsa_context* rsa = mbedtls_pk_rsa(pk_pub);
            luaL_buffinitsize(L, &b, out_size);
            while (value_sz > 0) {
                int in_sz = value_sz > RSA_ENCODE_LEN(rsa_sz) ? RSA_ENCODE_LEN(rsa_sz) : value_sz;
                int ret = mbedtls_rsa_pkcs1_encrypt(rsa, mbedtls_ctr_drbg_random, &TL_SSL_CTR_DRBG, in_sz, value_p, buf);
                if (ret != 0) {
                    luaL_error(L, "RSA encryption failed: %d", ret);
                }
                value_p += in_sz;
                value_sz -= in_sz;
                luaL_addlstring(&b, (cpchar)buf, rsa_sz);
            }
            luaL_pushresult(&b);
            return 1;
        }

        int verify(lua_State* L, std::string_view value, std::string_view sig) {
            if (mbedtls_pk_get_type(&pk_pub) != MBEDTLS_PK_RSA) {
                luaL_error(L, "rsa pubkey not initialized!");
            }
            uint8_t hash[SHA256_DIGEST_SIZE];
            mbedtls_sha256((upchar)value.data(), value.size(), hash, 0);
            int ret = mbedtls_pk_verify(&pk_pub, MBEDTLS_MD_SHA256, hash, SHA256_DIGEST_SIZE, (upchar)sig.data(), sig.size());
            lua_pushboolean(L, ret == 0);
            return 1;
        }

        int sign(lua_State* L, std::string_view value) {
            if (mbedtls_pk_get_type(&pk_pri) != MBEDTLS_PK_RSA) {
                luaL_error(L, "rsa prikey not initialized!");
            }
            size_t sig_len = 0;
            uint8_t buf[RSA_BUF_SIZE];
            uint8_t hash[SHA256_DIGEST_SIZE];
            mbedtls_sha256((upchar)value.data(), value.size(), hash, 0);
            int ret = mbedtls_pk_sign(&pk_pri, MBEDTLS_MD_SHA256, hash, SHA256_DIGEST_SIZE, buf, RSA_BUF_SIZE, &sig_len, mbedtls_ctr_drbg_random, &TL_SSL_CTR_DRBG);
            if (ret != 0) {
                luaL_error(L, "RSA signing failed: %d", ret);
            }
            lua_pushlstring(L, (cpchar)buf, sig_len);
            return 1;
        }

        int decrypt(lua_State* L, std::string_view value) {
            if (mbedtls_pk_get_type(&pk_pri) != MBEDTLS_PK_RSA) {
                luaL_error(L, "rsa prikey not initialized!");
            }
            luaL_Buffer b;
            size_t out_len = 0;
            size_t value_sz = value.size();
            uint8_t buf[RSA_BUF_SIZE];
            size_t out_size = RSA_DECODE_OUT_SIZE(value_sz, rsa_sz);
            upchar value_p = (upchar)value.data();
            luaL_buffinitsize(L, &b, out_size);
            mbedtls_rsa_context* rsa = mbedtls_pk_rsa(pk_pri);
            while (value_sz > 0) {
                size_t in_sz = value_sz > rsa_sz ? rsa_sz : value_sz;
                int ret = mbedtls_rsa_pkcs1_decrypt(rsa, mbedtls_ctr_drbg_random, &TL_SSL_CTR_DRBG, &out_len, value_p, buf, in_sz);
                if (ret != 0) {
                    luaL_error(L, "RSA decrypt failed: %d", ret);
                }
                value_p += in_sz;
                value_sz -= in_sz;
                luaL_addlstring(&b, (cpchar)buf, out_len);
            }
            luaL_pushresult(&b);
            return 1;
        }
    private:
        size_t rsa_sz = 0;
        mbedtls_pk_context pk_pub;
        mbedtls_pk_context pk_pri;
    };

    class tlscodec : public codec_base {
    public:
        ~tlscodec() {
            mbedtls_ssl_free(&ssl);
            m_inbuf.clean();
        }

        virtual int load_packet(size_t data_len) override {
            if (!m_slice) return 0;
            return data_len;
        }

        virtual uint8_t* encode(lua_State* L, int index, size_t* len) override {
            if (!is_handshake) {
                tls_handshake(L);
                return m_buf->drain(len);
            }
            size_t slen = 0;
            uint8_t* body = nullptr;
            if (m_hcodec) {
                body = m_hcodec->encode(L, index, &slen);
            } else {
                body = (uint8_t*)(lua_tolstring(L, index, &slen));
            }
            while (slen > 0) {
                size_t written = mbedtls_ssl_write(&ssl, body, slen);
                if (written < 0) tls_error(L, "mbedtls_ssl_write", written);
                if (written == 0) break;
                body += written;
                slen -= written;
            }
            return m_buf->drain(len);
        }

        virtual size_t decode(lua_State* L) override {
            size_t sz = m_slice->size();
            if (!is_handshake) {
                tls_handshake(L, true);
                m_packet_len = sz - m_slice->size();
                lua_push_object(L, this);
                return 1;
            }
            do {
                uint8_t* outbuff = m_inbuf.peek_space(SSL_TLS_READ_SIZE);
                int read = mbedtls_ssl_read(&ssl, outbuff, SSL_TLS_READ_SIZE);
                if (read == 0) break;
                if (read < 0) {
                    if (read == MBEDTLS_ERR_SSL_WANT_READ) break;
                    tls_error(L, "mbedtls_ssl_read", read, true);
                }
                m_inbuf.pop_space(read);
            } while (true);
            m_packet_len = sz - m_slice->size();
            if (!m_inbuf.empty()) {
                m_hcodec->set_slice(m_inbuf.get_slice());
                if (m_hcodec->load_packet(m_inbuf.size()) > 0) {
                    auto argnum = m_hcodec->decode(L);
                    m_inbuf.pop_size(m_hcodec->get_packet_len());
                    return argnum;
                }
            }
            throw std::length_error("http text not full");
        }

        int isfinish(lua_State* L) {
            lua_pushboolean(L, is_handshake);
            if (is_handshake) {
                const char* alpn_proto = mbedtls_ssl_get_alpn_protocol(&ssl);
                size_t alpn_len = alpn_proto ? std::strlen(alpn_proto) : 0;
                lua_pushlstring(L, alpn_proto, alpn_len);
                return 2;
            }
            return 1;
        }

        void set_codec(codec_base* codec) {
            m_hcodec = codec;
        }

        void init_tls(lua_State* L, char* hostname, cpchar protos) {
            mbedtls_ssl_init(&ssl);
            auto conf = hostname ? &TL_SSL_CLI_CONF : &TL_SSL_SER_CONF;
            if (int ret = mbedtls_ssl_setup(&ssl, conf); ret != 0) {
                tls_error(L, "mbedtls_ssl_setup", ret);
            }
            if (hostname) mbedtls_ssl_set_hostname(&ssl, hostname);
            mbedtls_ssl_set_bio(&ssl, this, ssl_send_cb, ssl_recv_cb, nullptr);
            if (protos) {
                const char* alpn_list[] = {protos, nullptr};
                if (int ret = mbedtls_ssl_conf_alpn_protocols(conf, alpn_list); ret != 0) {
                    tls_error(L, "mbedtls_ssl_conf_alpn_protocols", ret);
                }
            }
        }

    protected:
        void tls_handshake(lua_State* L, bool exception = false) {
            int ret = mbedtls_ssl_handshake(&ssl);
            if (ret == 0) {
                is_handshake = true;
                return;
            }
            if (ret != MBEDTLS_ERR_SSL_WANT_READ && ret != MBEDTLS_ERR_SSL_WANT_WRITE) {
                tls_error(L, "mbedtls_ssl_handshake", ret, exception);
            }
        }
        void tls_error(lua_State* L, cpchar func, int err, bool exception = false) {
            char buf[128];
            mbedtls_strerror(err, buf, sizeof(buf));
            if (exception) {
                throw lua_exception("{} error: {}", func, buf);
            } else {
                luaL_error(L, "%s error:%d, msg:%s, ret:%d", func, err, buf, err);
            }
        }

    private:
        static int ssl_send_cb(void* ctx, const unsigned char* buf, size_t len) {
            tlscodec* codec = reinterpret_cast<tlscodec*>(ctx);
            codec->m_buf->push_data(buf, len);
            return len;
        }

        static int ssl_recv_cb(void* ctx, unsigned char* buf, size_t len) {
            tlscodec* codec = reinterpret_cast<tlscodec*>(ctx);
            if (codec->m_slice && codec->m_slice->pop(buf, len)) return len;
            return MBEDTLS_ERR_SSL_WANT_READ;
        }
        
    protected:
        luabuf m_inbuf;
        mbedtls_ssl_context ssl;
        codec_base* m_hcodec = nullptr;
        bool is_handshake = false;
    };
}
