#pragma once
#include <cstring>
#include "lua_base.h"

namespace luakit {

    class slice {
    public:
        slice() {}
        slice(uint8_t* data, size_t size) {
            attach(data, size);
        }

        void __gc() {}

        inline size_t size() {
            return m_tail - m_head;
        }

        inline size_t empty() {
            return m_tail == m_head;
        }

        inline slice clone() {
            return slice(m_head, m_tail - m_head);
        }

        inline void attach(uint8_t* data, size_t size) {
            m_head = data;
            m_tail = data + size;
        }

        inline uint8_t* peek(size_t peek_len, size_t offset = 0) {
            size_t data_len = m_tail - m_head - offset;
            if (peek_len > 0 && data_len >= peek_len) {
                return m_head + offset;
            }
            return nullptr;
        }

        inline uint8_t* erase(size_t erase_len) {
            uint8_t* data = m_head;
            if (m_head + erase_len <= m_tail) {
                m_head += erase_len;
                return data;
            }
            return nullptr;
        }

        inline size_t pop(uint8_t* dest, size_t read_len) {
            size_t data_len = m_tail - m_head;
            if (read_len > 0 && data_len >= read_len) {
                memcpy(dest, m_head, read_len);
                m_head += read_len;
                return read_len;
            }
            return 0;
        }

        template <arithmetic T = uint8_t, size_t N = sizeof(T)>
        inline T read() {
            size_t data_len = m_tail - m_head;
            if (data_len >= N) {
                T val = *(T*)m_head;
                m_head += N;
                return val;
            }
            throw std::length_error("slice read not engugh!");
        }

        template <std::integral T = uint8_t, size_t N = sizeof(T)>
        inline T swap_read() {
            static_assert(N <= sizeof(T) && N > 0, "Invalid byte count N");
            size_t data_len = m_tail - m_head;
            if (data_len >= N) {
                T val = 0;
                memcpy(reinterpret_cast<char*>(&val) + sizeof(T) - N, m_head, N);
                m_head += N;
                return std::byteswap(val);
            }
            throw std::length_error("slice read not engugh!");
        }

        inline uint8_t* data(size_t* len) {
            *len = (size_t)(m_tail - m_head);
            return m_head;
        }

        inline uint8_t* head() {
            return m_head;
        }

        inline std::string_view contents() {
            size_t len = (size_t)(m_tail - m_head);
            return std::string_view((const char*)m_head, len);
        }

        inline std::string_view eof() {
            uint8_t* head = m_head;
            m_head = m_tail;
            size_t len = (size_t)(m_tail - head);
            return std::string_view((const char*)head, len);
        }

        inline int check(lua_State* L) {
            size_t peek_len = lua_tointeger(L, 1);
            size_t data_len = m_tail - m_head;
            if (peek_len > 0 && data_len >= peek_len) {
                lua_pushlstring(L, (const char*)m_head, peek_len);
                return 1;
            }
            return 0;
        }

        inline int recv(lua_State* L) {
            size_t data_len = m_tail - m_head;
            size_t read_len = lua_tointeger(L, 1);
            if (read_len > 0 && data_len >= read_len) {
                lua_pushlstring(L, (const char*)m_head, read_len);
                m_head += read_len;
                return 1;
            }
            return 0;
        }

        inline int string(lua_State* L) {
            size_t len = (size_t)(m_tail - m_head);
            lua_pushlstring(L, (const char*)m_head, len);
            return 1;
        }
        
    protected:
        uint8_t* m_head = nullptr;
        uint8_t* m_tail = nullptr;
    };
}
