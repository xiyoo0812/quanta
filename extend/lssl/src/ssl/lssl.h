
#pragma once

#include <wolfssl/openssl/ssl.h>

#include "lua_kit.h"

using namespace luakit;

#define RSA_PADDING_LEN             11
#define SSL_TLS_READ_SIZE           1024
#define RSA_ENCODE_LEN(m)           (m) - RSA_PADDING_LEN
#define BASE64_DECODE_OUT_SIZE(s)   ((unsigned int)(((s) / 4) * 3))
#define BASE64_ENCODE_OUT_SIZE(s)   ((unsigned int)((((s) + 2) / 3) * 4 + 1))
#define RSA_DECODE_OUT_SIZE(s, m)   (((s) + (m) - 1) / (m)) * (RSA_ENCODE_LEN(m)) + 1
#define RSA_ENCODE_OUT_SIZE(s, m)   (((s) + (RSA_ENCODE_LEN(m)) - 1) / (RSA_ENCODE_LEN(m))) * (m) + 1

namespace lssl {
    class lua_rsa_key {
    public:
        ~lua_rsa_key () {
            if (rsa) RSA_free(rsa);
        }

        bool init_pubkey(std::string_view& pkey) {
            if (rsa) RSA_free(rsa);
            size_t key_len = pkey.size();
            uint32_t b64_len = BASE64_DECODE_OUT_SIZE(key_len);
            unsigned char* b64_key = (unsigned char*)malloc(b64_len);
            if (Base64_Decode((const unsigned char*)pkey.data(), key_len, b64_key, &b64_len) != 0) {
                free(b64_key);
                return false;
            }
            rsa = d2i_RSAPublicKey(nullptr, (const unsigned char**)&b64_key, b64_len);
            if (rsa) rsa_sz = RSA_size(rsa);
            free(b64_key);
            return rsa != nullptr;
        }

        bool init_prikey(std::string_view& pkey) {
            if (rsa) RSA_free(rsa);
            size_t key_len = pkey.size();
            uint32_t b64_len = BASE64_DECODE_OUT_SIZE(key_len);
            unsigned char* b64_key = (unsigned char*)malloc(b64_len);
            if (Base64_Decode((const unsigned char*)pkey.data(), key_len, b64_key, &b64_len) != 0) {
                free(b64_key);
                return false;
            }
            rsa = d2i_RSAPrivateKey(nullptr, (const unsigned char**)&b64_key, key_len);
            if (rsa) rsa_sz = RSA_size(rsa);
            free(b64_key);
            return rsa != nullptr;
        }

        int pub_encode(lua_State* L, std::string_view value) {
            if (rsa == nullptr) {
                luaL_error(L, "rsa key not init!");
            }
            luaL_Buffer b;
            size_t value_sz = value.size();
            size_t out_size = RSA_ENCODE_OUT_SIZE(value_sz, rsa_sz);
            unsigned char* value_p = (unsigned char*)value.data();
            luaL_buffinitsize(L, &b, out_size);
            while (value_sz > 0) {
                int in_sz = value_sz > RSA_ENCODE_LEN(rsa_sz) ? RSA_ENCODE_LEN(rsa_sz) : value_sz;
                int len = RSA_public_encrypt(in_sz, value_p, (unsigned char*)buf, rsa, RSA_PKCS1_PADDING);
                if (len <= 0) {
                    luaL_error(L, "rsa pubkey encrypt failed!");
                }
                value_p += in_sz;
                value_sz -= in_sz;
                luaL_addlstring(&b, buf, len);
            }
            luaL_pushresult(&b);
            return 1;
        }

        int pub_decode(lua_State* L, std::string_view value) {
            if (rsa == nullptr) {
                luaL_error(L, "rsa pubkey not init!");
            }
            luaL_Buffer b;
            size_t value_sz = value.size();
            size_t out_size = RSA_DECODE_OUT_SIZE(value_sz, rsa_sz);
            unsigned char* value_p = (unsigned char*)value.data();
            luaL_buffinitsize(L, &b, out_size);
            while (value_sz > 0) {
                int in_sz = value_sz > rsa_sz ? rsa_sz : value_sz;
                int len = RSA_public_decrypt(in_sz, value_p, (unsigned char*)buf, rsa, RSA_PKCS1_PADDING);
                if (len <= 0) {
                    luaL_error(L, "rsa pubkey decode failed!");
                }
                value_p += in_sz;
                value_sz -= in_sz;
                luaL_addlstring(&b, buf, len);
            }
            luaL_pushresult(&b);
            return 1;
        }

        int pri_encode(lua_State* L, std::string_view value) {
            if (rsa == nullptr) {
                luaL_error(L, "rsa prikey not init!");
            }
            luaL_Buffer b;
            size_t value_sz = value.size();
            size_t out_size = RSA_ENCODE_OUT_SIZE(value_sz, rsa_sz);
            unsigned char* value_p = (unsigned char*)value.data();
            luaL_buffinitsize(L, &b, out_size);
            while (value_sz > 0) {
                int in_sz = value_sz > RSA_ENCODE_LEN(rsa_sz) ? RSA_ENCODE_LEN(rsa_sz) : value_sz;
                int len = RSA_private_encrypt(in_sz, value_p, (unsigned char*)buf, rsa, RSA_PKCS1_PADDING);
                if (len <= 0) {
                    luaL_error(L, "rsa prikey encode failed!");
                }
                value_p += in_sz;
                value_sz -= in_sz;
                luaL_addlstring(&b, buf, len);
            }
            luaL_pushresult(&b);
            return 1;
        }

        int pri_decode(lua_State* L, std::string_view value) {
            if (rsa == nullptr) {
                luaL_error(L, "rsa prikey not init!");
            }
            luaL_Buffer b;
            size_t value_sz = value.size();
            size_t out_size = RSA_DECODE_OUT_SIZE(value_sz, rsa_sz);
            unsigned char* value_p = (unsigned char*)value.data();
            luaL_buffinitsize(L, &b, out_size);
            while (value_sz > 0) {
                int in_sz = value_sz > rsa_sz ? rsa_sz : value_sz;
                int len = RSA_private_decrypt(in_sz, value_p, (unsigned char*)buf, rsa, RSA_PKCS1_PADDING);
                if (len <= 0) {
                    luaL_error(L, "rsa prikey decode failed!");
                }
                value_p += in_sz;
                value_sz -= in_sz;
                luaL_addlstring(&b, buf, len);
            }
            luaL_pushresult(&b);
            return 1;
        }
    private:
        size_t rsa_sz = 0;
        RSA* rsa = nullptr;
        char buf[RSA_MAX_SIZE / 8];
    };

    class tlscodec : public codec_base {
    public:
        ~tlscodec() {
            if (ssl) SSL_free(ssl);
            if (ctx) SSL_CTX_free(ctx);
        }

        virtual int load_packet(size_t data_len) {
            if (!m_slice) return 0;
            return data_len;
        }

        virtual uint8_t* encode(lua_State* L, int index, size_t* len) {
            if (!is_handshake) {
                uint8_t* data = (uint8_t*)lua_tolstring(L, index, len);
                if (*len > 0) bio_write(L, data, *len);
                tls_handshake(L);
                return m_buf->data(len);
            }
            size_t slen = 0;
            uint8_t* body = m_hcodec->encode(L, index, &slen);
            while (slen > 0) {
                int written = SSL_write(ssl, body, slen);
                if (written <= 0 || written > slen) {
                    int err = SSL_get_error(ssl, written);
                    ERR_clear_error();
                    luaL_error(L, "SSL_write error:%d", err);
                }
                body += written;
                slen -= written;
            }
            bio_read(L);
            return m_buf->data(len);
        }

        virtual size_t decode(lua_State* L) {
            size_t sz = m_slice->size();
            if (!is_handshake) {
                int top = lua_gettop(L);
                lua_pushstring(L, "TLS");
                lua_push_object(L, this);
                lua_pushlstring(L, (const char*)m_slice->head(), sz);
                m_slice->erase(sz);
                m_packet_len = sz;
                return lua_gettop(L) - top;
            }
            m_buf->clean();
            bio_write(L, m_slice->head(), sz);
            do {
                uint8_t* outbuff = m_buf->peek_space(SSL_TLS_READ_SIZE);
                int read = SSL_read(ssl, outbuff, sizeof(SSL_TLS_READ_SIZE));
                if (read == 0) break;
                if (read < 0 || read > SSL_TLS_READ_SIZE) {
                    int err = SSL_get_error(ssl, read);
                    ERR_clear_error();
                    if (err == SSL_ERROR_WANT_READ || err == SSL_ERROR_WANT_WRITE) {
                        break;
                    }
                    throw lua_exception("SSL_read error:%d", err);
                }
                m_buf->pop_space(read);
            } while (true);
            m_slice->erase(sz);
            m_packet_len = sz;
            m_hcodec->set_slice(m_buf->get_slice());
            return m_hcodec->decode(L);
        }

        bool isfinish() {
            is_handshake = SSL_is_init_finished(ssl);
            return is_handshake;
        }

        void set_codec(codec_base* codec) {
            m_hcodec = codec;
        }

        int init_tls(lua_State* L, bool is_client) {
            ctx = SSL_CTX_new(SSLv23_method());
            if (!ctx) {
                char buf[256];
                ERR_error_string_n(ERR_get_error(), buf, sizeof(buf));
                luaL_error(L, "SSL_CTX_new faild. %s\n", buf);
            }
            ssl = SSL_new(ctx);
            if (!ssl) luaL_error(L, "SSL_new faild");
            in_bio = BIO_new(BIO_s_mem());
            if (!in_bio) luaL_error(L, "new in bio faild");
            out_bio = BIO_new(BIO_s_mem());
            if (!out_bio) luaL_error(L, "new out bio faild");
            BIO_set_mem_eof_return(in_bio, -1);
            BIO_set_mem_eof_return(out_bio, -1);
            SSL_set_bio(ssl, in_bio, out_bio);
            if (is_client) {
                SSL_set_connect_state(ssl);
            } else {
                SSL_set_accept_state(ssl);
            }
            return 0;
        }

        int set_ciphers(lua_State* L, std::string_view cipher) {
            if (int ret = SSL_CTX_set_tlsext_use_srtp(ctx, cipher.data()) != 0) {
                luaL_error(L, "SSL_CTX_set_tlsext_use_srtp error: %d", ret);
            }
            return 0;
        }

        int set_cert(lua_State* L, std::string_view certfile, std::string_view key) {
            if (int ret = SSL_CTX_use_certificate_chain_file(ctx, certfile.data()) != 1) {
                luaL_error(L, "SSL_CTX_use_certificate_chain_file error:%d", ret);
            }
            if (int ret = SSL_CTX_use_PrivateKey_file(ctx, key.data(), SSL_FILETYPE_PEM) != 1) {
                luaL_error(L, "SSL_CTX_use_PrivateKey_file error:%d", ret);
            }
            if (int ret = SSL_CTX_check_private_key(ctx) != 1) {
                luaL_error(L, "SSL_CTX_check_private_key error:%d", ret);
            }
            return 0;
        }

    protected:
        void tls_handshake(lua_State* L) {
            is_handshake = SSL_is_init_finished(ssl);
            if (is_handshake) return;
            int ret = SSL_do_handshake(ssl);
            if (ret == 1) {
                return;
            }
            if (ret < 0) {
                bool dshake = SSL_is_init_finished(ssl);
                int err = SSL_get_error(ssl, ret);
                ERR_clear_error();
                if (err == SSL_ERROR_WANT_READ || err == SSL_ERROR_WANT_WRITE) {
                    bio_read(L);
                }
                return;
            }
            bool dshake = SSL_is_init_finished(ssl);
            int err = SSL_get_error(ssl, ret);
            ERR_clear_error();
            luaL_error(L, "SSL_do_handshake error:%d ret:%d", err, ret);
        }

        void bio_write(lua_State* L, uint8_t* data, size_t sz) {
            while (sz > 0) {
                int written = BIO_write(in_bio, data, sz);
                if (written <= 0 || written > sz) {
                    throw lua_exception("BIO_write error:%d", written);
                }
                sz -= written;
                data += written;
            }
        }

        void bio_read(lua_State* L) {
            m_buf->clean();
            int pending = BIO_ctrl_pending(out_bio);
            while (pending > 0) {
                uint8_t* outbuff = m_buf->peek_space(SSL_TLS_READ_SIZE);
                int read = BIO_read(out_bio, outbuff, SSL_TLS_READ_SIZE);
                if (read <= 0 || read > SSL_TLS_READ_SIZE) {
                    luaL_error(L, "BIO_read error:%d", read);
                }
                m_buf->pop_space(read);
                pending = BIO_ctrl_pending(out_bio);
            }
        }

    protected:
        SSL* ssl = nullptr;
        BIO* in_bio = nullptr;
        BIO* out_bio = nullptr;
        SSL_CTX* ctx = nullptr;
        codec_base* m_hcodec = nullptr;
        bool is_handshake = false;
    };
}
