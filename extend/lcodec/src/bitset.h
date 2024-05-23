#pragma once

#include <bitset>
#include <string>
#include <stdlib.h>

namespace lcodec {

    template <std::size_t N>
    std::string lua_bitset_new(std::string val) {
        std::bitset<N> bit(val);
        return bit.to_string();
    }

    template <std::size_t N>
    bool lua_bitset_get(std::string val, size_t pos) {
        std::bitset<N> bit(val);
        return bit[pos - 1];
    }

    template <std::size_t N>
    std::string lua_bitset_set(std::string val, size_t pos, bool bval) {
        std::bitset<N> bit(val);
        return bit.set(pos - 1, bval).to_string();
    }

    template <std::size_t N>
    std::string lua_bitset_flip(std::string val, size_t pos) {
        std::bitset<N> bit(val);
        return bit.flip(pos - 1).to_string();
    }

    template <std::size_t N>
    std::string lua_bitset_reset(std::string val, size_t pos) {
        std::bitset<N> bit(val);
        if (pos == 0) {
            return bit.reset().to_string();
        }
        return bit.reset(pos - 1).to_string();
    }

    template <std::size_t N>
    bool lua_bitset_check(std::string val, size_t len) {
        if (len > N) return false;
        std::bitset<N> bit(val);
        for (size_t i = 0; i < len; ++i) {
            if (!bit[i]) return false;
        }
        return true;
    }
}
