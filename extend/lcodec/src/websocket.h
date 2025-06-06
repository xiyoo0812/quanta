#pragma once

#include "lua_kit.h"

using namespace std;
using namespace luakit;

namespace lcodec {

    class wsscodec : public codec_base {
    public:
        virtual int load_packet(size_t data_len) {
            if (!m_slice) return 0;
            uint8_t* payload = (uint8_t*)m_slice->peek(sizeof(uint8_t), 1);
            if (!payload) return 0;
            uint8_t masklen = (((*payload) & 0x80) == 0x80) ? 4 : 0;
            uint8_t payloadlen = (*payload) & 0x7f;
            if (payloadlen < 0x7e) {
                m_packet_len = masklen + payloadlen + sizeof(uint16_t);
                return m_packet_len;
            }
            size_t ext_len = (payloadlen == 0x7f) ? 8 : 2;
            uint8_t* data = m_slice->peek(ext_len, sizeof(uint16_t));
            if (!data) return 0;
            size_t length = (payloadlen == 0x7f) ? byteswap8(*(uint64_t*)data) : byteswap2(*(uint16_t*)data);
            m_packet_len = masklen + ext_len + length + sizeof(uint16_t);
            if (m_packet_len > m_slice->size()) return 0;
            return m_packet_len;
        }

        virtual uint8_t* encode(lua_State* L, int index, size_t* len) {
            m_buf->clean();
            uint8_t* body = nullptr;
            size_t opcode = lua_tointeger(L, index);
            if (lua_type(L, index + 1) == LUA_TTABLE) {
                if (!m_codec) luaL_error(L, "ws encode table need a codec!");
                body = m_codec->encode(L, index + 1, len);
            } else {
                body = (uint8_t*)lua_tolstring(L, index + 1, len);
            }
            size_t masklen = m_mask.size();
            uint8_t maskflag = masklen > 0 ? 0x80 : 0;
            m_buf->write<uint8_t>((0x80 | opcode));
            if (*len < 0x7e) {
                m_buf->write<uint8_t>(maskflag | *len);
            } else if (*len <= 0xffff) {
                m_buf->write<uint8_t>(maskflag | 0x7e);
                m_buf->write<uint16_t>(byteswap2(*len));
            } else {
                m_buf->write<uint8_t>(maskflag | 0x7f);
                m_buf->write<uint64_t>(byteswap8(*len));
            }
            if (masklen > 0) {
                m_buf->push_data((uint8_t*)m_mask.data(), masklen);
                xor_byte((char*)body, m_mask.data(), *len, masklen, m_buf);
            } else {
                m_buf->push_data(body, *len);
            }
            return m_buf->data(len);
        }

        virtual size_t decode(lua_State* L) {
            uint8_t head = *(uint8_t*)m_slice->read<uint8_t>();
            if ((head & 0x80) != 0x80) throw lua_exception("sharded packet not suppert!");
            uint8_t payload  = *(uint8_t*)m_slice->read<uint8_t>();
            uint8_t opcode = head & 0xf;
            bool mask = ((payload & 0x80) == 0x80);
            payload = payload & 0x7f;
            if (payload >= 0x7e) {
                m_slice->erase((payload == 0x7f) ? 8 : 2);
            }
            int top = lua_gettop(L);
            lua_pushstring(L, "WSS");
            lua_pushinteger(L, opcode);
            if (mask) {
                size_t data_len;
                char* maskkey = (char*)m_slice->erase(4);
                char* data = (char*)m_slice->data(&data_len);
                xor_byte(data, maskkey, data_len, 4);
            }
            size_t osize = m_slice->size();
            if (m_codec && opcode == 0x02) {
                m_codec->set_slice(m_slice);
                m_codec->decode(L);
            } else {
                lua_pushlstring(L, (char*)m_slice->head(), osize);
            }
            return lua_gettop(L) - top;
        }

        void set_codec(codec_base* codec) {
            m_codec = codec;
        }

        void build_mask() {
            m_mask.resize(4);
            const char charset[] = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
            const size_t max_index = sizeof(charset) - 1;
            for (int i = 0; i < 4; ++i) {
                m_mask[i] = charset[std::rand() % max_index];
            }
        }

    protected:
        void xor_byte(char* buffer, char* mask, size_t blen, size_t mlen, luabuf* buf = nullptr) {
            auto data = buf ? buf->peek_space(blen) : (uint8_t*)buffer;
            for (size_t i = 0; i < blen; i++) {
                data[i] = buffer[i] ^ mask[i % mlen];
            }
            if (buf) buf->pop_space(blen);
        }

    protected:
        string m_mask = "";
        codec_base* m_codec = nullptr;
    };
}
