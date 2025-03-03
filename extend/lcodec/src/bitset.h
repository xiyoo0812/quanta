#pragma once

#include <vector>
#include <string>
#include <stdlib.h>

namespace lcodec {

    const size_t MAX_BITSET_SIZE = 1024;
    static char BITHEX[] = "0123456789abcdef";
    thread_local char bitset_buf[MAX_BITSET_SIZE];

    class bitset {
    public:
        bitset() {
            m_bits.resize(16, false);
        }

        char fromhex(unsigned char x) {
            if (x >= 'A' && x <= 'Z') return x - 'A' + 10;
            else if (x >= 'a' && x <= 'z') return x - 'a' + 10;
            else if (x >= '0' && x <= '9') return x - '0';
            else return x;
        }

        bool load(std::string_view val) {
            if (val.empty()) return false;
            size_t val_szie = val.size();
            if (val_szie > MAX_BITSET_SIZE) return false;
            m_bits.resize((val_szie + 7) / 8 * 8);
            for (size_t i = 0; i < val_szie; ++i) {
                m_bits[i] = (val[val_szie - i - 1] == '1');
            }
            return true;
        }

        bool loadhex(std::string_view val) {
            if (val.empty() || val.size() % 2 != 0) return false;
            if (val.size() * 4 > MAX_BITSET_SIZE) return false;
            m_bits.resize(val.size() * 4);
            for (size_t i = 0; i < val.size(); i += 2) {
                uint8_t hi = fromhex(val[i]);
                uint8_t low = fromhex(val[i + 1]);
                uint8_t byte = hi << 4 | low;
                for (size_t j = 0; j < 8; ++j) {
                    uint8_t flag = 1 << j;
                    m_bits[(i / 2) * 8 + j] = ((byte & flag) == flag);
                }
            }
            return true;
        }

        bool loadbin(std::string_view val) {
            if (val.empty()) return false;
            if (val.size() * 8 > MAX_BITSET_SIZE) return false;
            m_bits.resize(val.size() * 8);
            for (size_t i = 0; i < val.size(); ++i) {
                uint8_t byte = val[i];
                for (size_t j = 0; j < 8; ++j) {
                    uint8_t flag = 1 << j;
                    m_bits[i * 8 + j] = ((byte & flag) == flag);
                }
            }
            return true;
        }

        std::string_view binary() {
            size_t vsz = m_bits.size();
            size_t casz = (vsz + 7) / 8;
            for (size_t i = 0; i < casz; ++i) {
                char byte = 0;
                for (size_t j = 0; j < 8 && i * 8 + j < vsz; ++j) {
                    if (m_bits[i * 8 + j]) {
                        byte |= (1 << j);
                    }
                }
                bitset_buf[i] = byte;
            }
            return std::string_view(bitset_buf, casz);
        }

        std::string_view hex() {
            size_t vsz = m_bits.size();
            size_t casz = (vsz + 7) / 8;
            for (size_t i = 0; i < casz; ++i) {
                uint8_t byte = 0;
                for (size_t j = 0; j < 8 && i * 8 + j < vsz; ++j) {
                    if (m_bits[i * 8 + j]) {
                        byte |= (1 << j);
                    }
                }
                bitset_buf[i * 2] = BITHEX[byte >> 4];
                bitset_buf[i * 2 + 1] = BITHEX[byte & 0xf];
            }
            return std::string_view(bitset_buf, casz * 2);
        }
        
        std::string_view tostring(bool prefix) {
            int pos = 0;
            auto ite = m_bits.rend();
            for (auto it = m_bits.rbegin(); it != ite; ++it) {
                if (*it) prefix = true;
                if (prefix) bitset_buf[pos++] = *it ? '1' : '0';
            }
            return std::string_view(bitset_buf, pos);
        }

        bool get(size_t pos) {
            if (pos > m_bits.size() || pos == 0) return false;
            return m_bits[pos - 1];
        }

        bool set(size_t pos, bool bval) {
            if (pos > MAX_BITSET_SIZE || pos == 0) return false;
            if (pos > m_bits.size()) {
                size_t nsz = (m_bits.size() + 7) / 8 * 8;
                m_bits.resize(nsz);
            }
            m_bits[pos - 1] = bval;
            return true;
        }

        bool flip(size_t pos) {
            if (pos > m_bits.size() || pos == 0) return false;
            m_bits[pos - 1] = !m_bits[pos - 1];
            return true;
        }

        bool check(size_t pos) {
            if (pos > m_bits.size() || pos == 0) return false;
            for (size_t i = 0; i < pos; ++i) {
                if (!m_bits[i]) return false;
            }
            return true;
        }

        void reset(size_t pos) {
            if (pos == 0) {
                m_bits = { 0 };
                return;
            }
            if (pos <= m_bits.size()) {
                m_bits[pos - 1] = false;
            }
        }

    protected:
        std::vector<bool> m_bits = { 0 };
    };
}
