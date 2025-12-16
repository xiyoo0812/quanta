#pragma once

#include "lua_slice.h"

namespace luakit {

    const size_t BUFFER_DEF = 64 * 1024;        //64K
    const size_t BUFFER_MAX = 16 * 1024 * 1024; //16M
    const size_t ALIGN_SIZE = 16;               //水位

    class luabuf {
    public:
        luabuf() { _alloc(); }
        ~luabuf() { free(m_data); }

        inline void reset() {
            if (m_size != BUFFER_DEF) {
                m_data = (uint8_t*)realloc(m_data, BUFFER_DEF);
            }
            m_end = m_data + BUFFER_DEF;
            m_head = m_tail = m_data;
            m_size = BUFFER_DEF;
        }

        inline size_t size() {
            return m_tail - m_head;
        }

        inline size_t capacity() {
            return m_size;
        }

        inline size_t empty() {
            return m_tail == m_head;
        }

        inline uint8_t* head() {
            return m_head;
        }

        inline void clean() {
            size_t data_len = m_tail - m_head;
            if (m_size > m_max && data_len < BUFFER_DEF) {
                _resize(m_size / 2);
            }
            m_head = m_tail = m_data;
        }

        inline size_t copy(size_t offset, cpbyte src, size_t src_len) {
            if (offset + src_len <= m_size) {
                memmove(m_head + offset, src, src_len);
                return src_len;
            }
            return 0;
        }

        inline size_t hold_place(size_t offset) {
            size_t base = m_tail - m_head;
            pop_space(offset);
            return base;
        }

        inline slice* free_place(size_t base, size_t offset) {
            auto data = m_head + base + offset;
            size_t data_len = m_tail - data;
            m_tail = m_head + base;
            if (data_len > 0) {
                m_slice.attach(data, data_len);
                return &m_slice;
            }
            return nullptr;
        }

        inline size_t push_data(cpbyte src, size_t push_len) {
            uint8_t* target = peek_space(push_len);
            if (target) {
                memcpy(target, src, push_len);
                m_tail += push_len;
                return push_len;
            }
            return 0;
        }

        inline size_t pop_data(uint8_t* dest, size_t pop_len) {
            size_t data_len = m_tail - m_head;
            if (pop_len > 0 && data_len >= pop_len) {
                memcpy(dest, m_head, pop_len);
                m_head += pop_len;
                return pop_len;
            }
            return 0;
        }

        inline size_t pop_size(size_t erase_len) {
            if (m_head + erase_len <= m_tail) {
                m_head += erase_len;
                size_t data_len = (size_t)(m_tail - m_head);
                if (m_size > m_max && data_len < BUFFER_DEF) {
                    _regularize();
                    _resize(m_size / 2);
                }
                return erase_len;
            }
            return 0;
        }

        inline uint8_t* peek_data(size_t peek_len, size_t offset = 0) {
            size_t data_len = m_tail - m_head - offset;
            if (peek_len > 0 && data_len >= peek_len) {
                return m_head + offset;
            }
            return nullptr;
        }

        inline size_t pop_space(size_t space_len) {
            if (m_tail + space_len <= m_end) {
                m_tail += space_len;
                return space_len;
            }
            return 0;
        }

        inline slice* get_slice(size_t len = 0, uint32_t offset = 0) {
            size_t data_len = m_tail - (m_head + offset);
            m_slice.attach(m_head + offset, len == 0 ? data_len : len);
            return &m_slice;
        }

        inline uint8_t* peek_space(size_t len) {
            size_t space_len = m_end - m_tail;
            if (space_len < len) {
                space_len = _regularize();
                if (space_len < len) {
                    size_t nsize = m_size * 2;
                    size_t data_len = m_tail - m_head;
                    while (nsize - data_len < len) {
                        nsize *= 2;
                    }
                    if (nsize > BUFFER_MAX) {
                        return nullptr;
                    }
                    space_len = _resize(nsize);
                    if (space_len < len) {
                        return nullptr;
                    }
                }
            }
            return m_tail;
        }

        inline uint8_t* data(size_t* len) {
            *len = (size_t)(m_tail - m_head);
            return m_head;
        }

        inline vstring string() {
            size_t len = (size_t)(m_tail - m_head);
            return std::string_view((cpchar)m_head, len);
        }

        inline size_t write(cpchar src) {
            return push_data((cpbyte)src, strlen(src));
        }

        inline size_t write(cstring& src) {
            return push_data((cpbyte)src.c_str(), src.size());
        }

        inline size_t write(cvstring src) {
            return push_data((cpbyte)src.data(), src.size());
        }

        template <arithmetic T, size_t N = sizeof(T)>
        inline size_t write(T val) {
            T* target = (T*)peek_space(N);
            if (target) {
                *target = val;
                m_tail += N;
                return N;
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
            throw std::length_error("buff read not engugh!");
        }

        template <std::integral T, size_t N = sizeof(T)>
        inline size_t swap_write(T val) {
            static_assert(N <= sizeof(T) && N > 0, "invalid byte count N");
            auto target = peek_space(N);
            if (target) {
                val = byteswap(val);
                cpbyte src = reinterpret_cast<uint8_t*>(&val) + sizeof(T) - N;
                memcpy(target, src, N);
                m_tail += N;
                return N;
            }
            return 0;
        }

        template <std::integral T, size_t N = sizeof(T)>
        inline T swap_read() {
            static_assert(N <= sizeof(T) && N > 0, "invalid byte count N");
            size_t data_len = m_tail - m_head;
            if (data_len >= N) {
                T val = 0;
                memcpy(reinterpret_cast<char*>(&val) + sizeof(T) - N, m_head, N);
                m_head += N;
                return byteswap(val);
            }
            throw std::length_error(" buff read not engugh!");
        }

    protected:
        //整理内存
        size_t _regularize() {
            size_t data_len = (size_t)(m_tail - m_head);
            if (m_head > m_data) {
                if (data_len > 0) {
                    memmove(m_data, m_head, data_len);
                }
                m_tail = m_data + data_len;
                m_head = m_data;
            }
            return m_size - data_len;
        }

        //重新设置长度
        size_t _resize(size_t size) {
            size_t data_len = (size_t)(m_tail - m_head);
            if (m_size == size || size < data_len || size > BUFFER_MAX) {
                return m_end - m_tail;
            }
            m_data = (uint8_t*)realloc(m_data, size);
            m_tail = m_data + data_len;
            m_end = m_data + size;
            m_head = m_data;
            m_size = size;
            return size - data_len;
        }

        void _alloc() {
            m_data = (uint8_t*)malloc(BUFFER_DEF);
            m_size = BUFFER_DEF;
            m_head = m_tail = m_data;
            m_end = m_data + BUFFER_DEF;
            m_max = m_size * ALIGN_SIZE;
        }

    private:
        size_t m_max;
        size_t m_size;
        uint8_t* m_head;
        uint8_t* m_tail;
        uint8_t* m_end;
        uint8_t* m_data;
        slice m_slice;
    };
}
