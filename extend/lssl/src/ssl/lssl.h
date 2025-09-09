
#pragma once

#include <wolfssl/openssl/ssl.h>
#include <wolfssl/openssl/pem.h>

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
    static SSL_CTX* S_SSL_CTX   = nullptr;

    class lua_rsa_key {
    public:
        ~lua_rsa_key () {
            close();
        }

        void close() {
            if (rsa_pub) RSA_free(rsa_pub);
            if (rsa_pri) RSA_free(rsa_pri);
        }

        bool set_pubkey(std::string_view pkey) {
            if (rsa_pub) close();
            BIO* bio = BIO_new_mem_buf(pkey.data(), pkey.size());
            rsa_pub = PEM_read_bio_RSA_PUBKEY(bio, nullptr, nullptr, nullptr);
            if (rsa_pub) rsa_sz = RSA_size(rsa_pub);
            return rsa_pub != nullptr;
        }

        bool set_prikey(std::string_view pkey) {
            if (rsa_pri) close();
            BIO* bio = BIO_new_mem_buf(pkey.data(), pkey.size());
            rsa_pri = PEM_read_bio_RSAPrivateKey(bio, nullptr, nullptr, nullptr);
            if (rsa_pri) {
                rsa_sz = RSA_size(rsa_pri);
                rsa_pub = RSAPublicKey_dup(rsa_pri);
            }
            return rsa_pri != nullptr;
        }

        int encrypt(lua_State* L, std::string_view value) {
            if (rsa_pub == nullptr) {
                luaL_error(L, "rsa key not init!");
            }
            luaL_Buffer b;
            size_t value_sz = value.size();
            size_t out_size = RSA_ENCODE_OUT_SIZE(value_sz, rsa_sz);
            unsigned char* value_p = (unsigned char*)value.data();
            luaL_buffinitsize(L, &b, out_size);
            while (value_sz > 0) {
                int in_sz = value_sz > RSA_ENCODE_LEN(rsa_sz) ? RSA_ENCODE_LEN(rsa_sz) : value_sz;
                int len = RSA_public_encrypt(in_sz, value_p, (unsigned char*)buf, rsa_pub, RSA_PKCS1_PADDING);
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

        int verify(lua_State* L, std::string_view value, std::string_view sig) {
            if (rsa_pub == nullptr) {
                luaL_error(L, "rsa pubkey not init!");
            }
            uint32_t value_sz = value.size();
            unsigned char hash[SHA256_DIGEST_LENGTH];
            unsigned char* value_p = (unsigned char*)value.data();
            SHA256(value_p, value_sz, hash);
            unsigned char* sig_p = (unsigned char*)sig.data();
            int ret = RSA_verify(NID_sha256, hash, SHA256_DIGEST_LENGTH, sig_p, sig.size(), rsa_pub);
            lua_pushboolean(L, ret);
            return 1;
        }

        int sign(lua_State* L, std::string_view value) {
            if (rsa_pri == nullptr) {
                luaL_error(L, "rsa prikey not init!");
            }
            uint32_t value_sz = value.size();
            unsigned char hash[SHA256_DIGEST_LENGTH];
            unsigned char* value_p = (unsigned char*)value.data();
            SHA256(value_p, value_sz, hash);

            if (RSA_sign(NID_sha256, hash, SHA256_DIGEST_LENGTH, (unsigned char*)buf, &value_sz, rsa_pri) != 1) {
                luaL_error(L, "rsa prikey sign field!");
            }
            lua_pushlstring(L, (const char*)buf, value_sz);
            return 1;
        }

        int decrypt(lua_State* L, std::string_view value) {
            if (rsa_pri == nullptr) {
                luaL_error(L, "rsa prikey not init!");
            }
            luaL_Buffer b;
            size_t value_sz = value.size();
            size_t out_size = RSA_DECODE_OUT_SIZE(value_sz, rsa_sz);
            unsigned char* value_p = (unsigned char*)value.data();
            luaL_buffinitsize(L, &b, out_size);
            while (value_sz > 0) {
                int in_sz = value_sz > rsa_sz ? rsa_sz : value_sz;
                int len = RSA_private_decrypt(in_sz, value_p, (unsigned char*)buf, rsa_pri, RSA_PKCS1_PADDING);
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
        RSA* rsa_pub = nullptr;
        RSA* rsa_pri = nullptr;
        char buf[RSA_MAX_SIZE / 8];
    };

    class tlscodec : public codec_base {
    public:
        ~tlscodec() {
            if (ssl) SSL_free(ssl);
        }

        virtual int load_packet(size_t data_len) {
            if (!m_slice) return 0;
            return data_len;
        }

        virtual uint8_t* encode(lua_State* L, int index, size_t* len) {
            m_buf->clean();
            if (!is_handshake) {
                uint8_t* data = (uint8_t*)lua_tolstring(L, index, len);
                if (*len > 0) bio_write(L, data, *len);
                tls_handshake(L);
                return m_buf->data(len);
            }
            size_t slen;
            uint8_t* body = nullptr;
            if (m_hcodec) {
                body = m_hcodec->encode(L, index, &slen);
            } else {
                body = (uint8_t*)lua_tolstring(L, index, &slen);
            }
            while (slen > 0) {
                size_t written = SSL_write(ssl, body, slen);
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
                lua_push_object(L, this);
                lua_pushlstring(L, (const char*)m_slice->head(), sz);
                m_packet_len = sz;
                return lua_gettop(L) - top;
            }
            m_packet_len = sz;
            bio_write(L, m_slice->head(), sz);
            do {
                uint8_t* outbuff = m_buf->peek_space(SSL_TLS_READ_SIZE);
                int read = SSL_read(ssl, outbuff, SSL_TLS_READ_SIZE);
                if (read == 0) break;
                if (read < 0) {
                    int err = SSL_get_error(ssl, read);
                    if (err == SSL_ERROR_WANT_READ) break;
                    throw lua_exception("SSL_read error: {}", err);
                }
                sslbuf.append((char*)outbuff, read);
            } while (true);
            if (!sslbuf.empty()) {
                slice sli((uint8_t*)sslbuf.c_str(), sslbuf.size());
                m_hcodec->set_slice(&sli);
                if (m_hcodec->load_packet(sslbuf.size()) > 0) {
                    auto argnum = m_hcodec->decode(L);
                    sslbuf.erase(0, m_hcodec->get_packet_len());
                    return argnum;
                }
            }
            throw std::length_error("http text not full");
        }

        int isfinish(lua_State* L) {
            is_handshake = SSL_is_init_finished(ssl);
            lua_pushboolean(L, is_handshake);
            if (is_handshake) {
                unsigned int len;
                const unsigned char *data;
                SSL_get0_alpn_selected(ssl, &data, &len);
                lua_pushlstring(L, (const char*)data, len);
                return 2;
            }
            return 1;
        }

        void set_codec(codec_base* codec) {
            m_hcodec = codec;
        }

        void init_tls(lua_State* L, bool client, const char* protos) {
            if (!S_SSL_CTX) {
                char buf[256];
                ERR_error_string_n(ERR_get_error(), buf, sizeof(buf));
                luaL_error(L, "SSL_CTX_new faild. %s\n", buf);
            }
            ssl = SSL_new(S_SSL_CTX);
            if (!ssl) luaL_error(L, "SSL_new faild");
            in_bio = BIO_new(BIO_s_mem());
            if (!in_bio) luaL_error(L, "new in bio faild");
            out_bio = BIO_new(BIO_s_mem());
            if (!out_bio) luaL_error(L, "new out bio faild");
            BIO_set_mem_eof_return(in_bio, -1);
            BIO_set_mem_eof_return(out_bio, -1);
            SSL_set_bio(ssl, in_bio, out_bio);
            if (protos) {
                SSL_set_alpn_protos(ssl, (const unsigned char*)protos, strlen(protos));
            }
            if (client) {
                SSL_set_connect_state(ssl);
            } else {
                SSL_set_accept_state(ssl);
            }
        }

    protected:
        void tls_handshake(lua_State* L) {
            int ret = SSL_do_handshake(ssl);
            if (ret == SSL_SUCCESS) return;
            int err = SSL_get_error(ssl, ret);
            if (err == SSL_ERROR_WANT_READ) {
                bio_read(L);
                return;
            }
            luaL_error(L, "SSL_do_handshake error:%d ret:%d", err, ret);
        }

        void bio_write(lua_State* L, uint8_t* data, size_t sz) {
            while (sz > 0) {
                size_t written = BIO_write(in_bio, data, sz);
                if (written <= 0 || written > sz) {
                    throw lua_exception("BIO_write error: {}", written);
                }
                sz -= written;
                data += written;
            }
        }

        void bio_read(lua_State* L) {
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
        std::string sslbuf = "";
        codec_base* m_hcodec = nullptr;
        bool is_handshake = false;
    };
}
