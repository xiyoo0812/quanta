#pragma once
#include "mbedtls/md.h"
#include "mbedtls/ssl.h"
#include "mbedtls/error.h"
#include "mbedtls/base64.h"
#include "mbedtls/x509_crt.h"
#include "psa/crypto.h"

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

    inline void init_mbedtls_globals() {
        cpchar pers = "LUATLS";
        psa_crypto_init();
        mbedtls_pk_init(&TL_SSL_PKEY);
        mbedtls_x509_crt_init(&TL_SSL_SRVCERT);
        mbedtls_x509_crt_init(&TL_SSL_TRUSTED_CAS);
        mbedtls_ssl_config_defaults(&TL_SSL_CLI_CONF, MBEDTLS_SSL_IS_CLIENT, MBEDTLS_SSL_TRANSPORT_STREAM, MBEDTLS_SSL_PRESET_DEFAULT);
        mbedtls_ssl_config_defaults(&TL_SSL_SER_CONF, MBEDTLS_SSL_IS_SERVER, MBEDTLS_SSL_TRANSPORT_STREAM, MBEDTLS_SSL_PRESET_DEFAULT);
        mbedtls_ssl_conf_authmode(&TL_SSL_CLI_CONF, MBEDTLS_SSL_VERIFY_OPTIONAL);
    }

    inline void cleanup_mbedtls_globals() {
        mbedtls_x509_crt_free(&TL_SSL_TRUSTED_CAS);
        mbedtls_ssl_config_free(&TL_SSL_CLI_CONF);
        mbedtls_ssl_config_free(&TL_SSL_SER_CONF);
        mbedtls_x509_crt_free(&TL_SSL_SRVCERT);
        mbedtls_pk_free(&TL_SSL_PKEY);
    }

    inline psa_status_t load_psa_key(upchar key, size_t klen, psa_key_type_t tpe, psa_algorithm_t alg, psa_key_usage_t usage, psa_key_id_t& key_id) {
        psa_key_attributes_t attr = PSA_KEY_ATTRIBUTES_INIT;
        psa_set_key_type(&attr, tpe);
        psa_set_key_algorithm(&attr, alg);
        psa_set_key_usage_flags(&attr, usage);
        return psa_import_key(&attr, key, klen, &key_id);
    }

    class lua_rsa_key {
    public:
        ~lua_rsa_key() {
            if (enc_key) psa_destroy_key(enc_key);
            if (dec_key) psa_destroy_key(dec_key);
            if (sign_key) psa_destroy_key(sign_key);
            if (verify_key) psa_destroy_key(verify_key);
        }

        bool set_pubkey(std::string_view pem) {
            size_t der_len = 0;
            uint8_t der_data[1024];
            int ret = mbedtls_base64_decode(der_data, sizeof(der_data), &der_len, (upchar)pem.data(), pem.size());
            if (ret != 0) return false;
            return set_pubkey_der(der_data, der_len);
        }

        bool set_pubkey_der(upchar der_data, size_t der_len) {
            auto alg = PSA_ALG_RSA_PKCS1V15_CRYPT;
            auto usage = PSA_KEY_USAGE_ENCRYPT | PSA_KEY_USAGE_VERIFY_HASH;
            if (load_psa_key(der_data, der_len, PSA_KEY_TYPE_RSA_PUBLIC_KEY, alg, usage, enc_key) != 0)
                return false;
            alg = PSA_ALG_RSA_PKCS1V15_SIGN(PSA_ALG_SHA_256);
            if (load_psa_key(der_data, der_len, PSA_KEY_TYPE_RSA_PUBLIC_KEY, alg, usage, verify_key) != 0)
                return false;
            psa_key_attributes_t attr = PSA_KEY_ATTRIBUTES_INIT;
            psa_get_key_attributes(enc_key, &attr);
            rsa_sz = (psa_get_key_bits(&attr) + 7) / 8;
            return true;
        }

        bool set_prikey_der(upchar der_data, size_t der_len) {
            auto alg = PSA_ALG_RSA_PKCS1V15_CRYPT;
            auto usage = PSA_KEY_USAGE_DECRYPT | PSA_KEY_USAGE_SIGN_HASH;
            if (load_psa_key(der_data, der_len, PSA_KEY_TYPE_RSA_KEY_PAIR, alg, usage, dec_key) != 0)
                return false;
            alg = PSA_ALG_RSA_PKCS1V15_SIGN(PSA_ALG_SHA_256);
            if (load_psa_key(der_data, der_len, PSA_KEY_TYPE_RSA_KEY_PAIR, alg, usage, sign_key) != 0)
                return false;
            return true;
        }

        bool set_prikey(std::string_view pem) {
            size_t der_len = 0;
            uint8_t der_data[2048];
            int ret = mbedtls_base64_decode(der_data, sizeof(der_data), &der_len, (upchar)pem.data(), pem.size());
            if (ret != 0) return false;
            if (!set_prikey_der(der_data, der_len)) return false;
            if (psa_export_public_key(dec_key, der_data, sizeof(der_data), &der_len) != 0) return false;
            return set_pubkey_der(der_data, der_len);
        }

        int encrypt(lua_State* L, std::string_view value) {
            if (enc_key == 0) {
                luaL_error(L, "rsa pubkey not initialized!");
            }
            luaL_Buffer b;
            size_t value_sz = value.size();
            size_t out_size = RSA_ENCODE_OUT_SIZE(value_sz, rsa_sz);
            const uint8_t* value_p = reinterpret_cast<const uint8_t*>(value.data());
            luaL_buffinitsize(L, &b, out_size);
            while (value_sz > 0) {
                size_t in_len = (value_sz > RSA_ENCODE_LEN(rsa_sz)) ? RSA_ENCODE_LEN(rsa_sz) : value_sz;
                uint8_t out_buf[RSA_BUF_SIZE];
                size_t out_len = 0;
                auto status = psa_asymmetric_encrypt(enc_key, PSA_ALG_RSA_PKCS1V15_CRYPT, value_p, in_len,
                    nullptr, 0, out_buf, sizeof(out_buf), &out_len);
                if (status != 0) {
                    luaL_error(L, "RSA encryption failed: %d", (int)status);
                }
                luaL_addlstring(&b, reinterpret_cast<const char*>(out_buf), out_len);
                value_p += in_len;
                value_sz -= in_len;
            }
            luaL_pushresult(&b);
            return 1;
        }

        int verify(lua_State* L, std::string_view value, std::string_view sig) {
            if (verify_key == 0) {
                luaL_error(L, "rsa pubkey not initialized!");
            }
            size_t hash_len = 0;
            uint8_t hash[SHA256_DIGEST_SIZE];
            auto alg = PSA_ALG_RSA_PKCS1V15_SIGN(PSA_ALG_SHA_256);
            psa_hash_compute(PSA_ALG_SHA_256, (upchar)value.data(), value.size(), hash, sizeof(hash), &hash_len);
            auto status = psa_verify_hash(verify_key, alg, hash, hash_len, (upchar)sig.data(), sig.size());
            lua_pushboolean(L, status == 0);
            return 1;
        }

        int sign(lua_State* L, std::string_view value) {
            if (sign_key == 0) {
                luaL_error(L, "rsa prikey not initialized!");
            }
            size_t sig_len = 0;
            uint8_t sig_buf[RSA_BUF_SIZE];
            uint8_t hash[SHA256_DIGEST_SIZE];
            auto alg = PSA_ALG_RSA_PKCS1V15_SIGN(PSA_ALG_SHA_256);
            psa_hash_compute(PSA_ALG_SHA_256, (upchar)value.data(), value.size(), hash, sizeof(hash), &sig_len);
            auto status = psa_sign_hash(sign_key, alg, hash, sizeof(hash), sig_buf, sizeof(sig_buf), &sig_len);
            if (status != 0) {
                luaL_error(L, "RSA signing failed: %d", (int)status);
            }
            lua_pushlstring(L, (cpchar)sig_buf, sig_len);
            return 1;
        }

        int decrypt(lua_State* L, std::string_view value) {
            if (dec_key == 0) {
                luaL_error(L, "rsa prikey not initialized!");
            }
            luaL_Buffer b;
            size_t out_len = 0;
            size_t value_sz = value.size();
            uint8_t buf[RSA_BUF_SIZE];
            size_t out_size = RSA_DECODE_OUT_SIZE(value_sz, rsa_sz);
            upchar value_p = (upchar)value.data();
            luaL_buffinitsize(L, &b, out_size);
            while (value_sz > 0) {
                auto alg = PSA_ALG_RSA_PKCS1V15_CRYPT;
                size_t in_sz = (value_sz > rsa_sz) ? rsa_sz : value_sz;
                auto status = psa_asymmetric_decrypt(dec_key, alg, value_p, in_sz, nullptr, 0, buf, sizeof(buf), &out_len);
                if (status != 0) {
                    luaL_error(L, "RSA decrypt failed: %d", (int)status);
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
        psa_key_id_t enc_key = 0;
        psa_key_id_t dec_key = 0;
        psa_key_id_t sign_key = 0;
        psa_key_id_t verify_key = 0;
    };

    class tlscodec : public codec_base {
    public:
        ~tlscodec() {
            mbedtls_ssl_free(&ssl);
            m_outbuf.clean();
            m_inbuf.clean();
        }

        virtual int load_packet(size_t data_len) override {
            if (!m_slice) return 0;
            return data_len;
        }

        virtual uint8_t* encode(lua_State* L, int index, size_t* len) override {
            if (!is_handshake) {
                tls_handshake(L);
                return m_outbuf.drain(len);
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
            return m_outbuf.drain(len);
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
                    if (read == MBEDTLS_ERR_SSL_RECEIVED_NEW_SESSION_TICKET) continue;
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
                throw lua_exception("{} error: {}({})", func, buf, err);
            } else {
                luaL_error(L, "%s error:%d, msg:%s", func, err, buf, err);
            }
        }

    private:
        static int ssl_send_cb(void* ctx, const unsigned char* buf, size_t len) {
            tlscodec* codec = reinterpret_cast<tlscodec*>(ctx);
            codec->m_outbuf.push_data(buf, len);
            return len;
        }

        static int ssl_recv_cb(void* ctx, unsigned char* buf, size_t len) {
            tlscodec* codec = reinterpret_cast<tlscodec*>(ctx);
            if (codec->m_slice && codec->m_slice->pop(buf, len)) return len;
            return MBEDTLS_ERR_SSL_WANT_READ;
        }
        
    protected:
        luabuf m_inbuf, m_outbuf;
        mbedtls_ssl_context ssl;
        codec_base* m_hcodec = nullptr;
        bool is_handshake = false;
    };
}
