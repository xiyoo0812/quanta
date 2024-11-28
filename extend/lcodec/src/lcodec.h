
#pragma once

#include "lua_kit.h"

inline uint16_t byteswap2(uint16_t const u16) {
    uint8_t* data = (uint8_t*)&u16;
    return ((uint16_t)data[1] << 0) | ((uint16_t)data[0] << 8);
}

inline uint32_t byteswap4(uint32_t const u32) {
    uint8_t* data = (uint8_t*)&u32;
    return ((uint32_t)data[3] << 0) | ((uint32_t)data[2] << 8)
        | ((uint32_t)data[1] << 16) | ((uint32_t)data[0] << 24);
}

inline uint64_t byteswap8(uint64_t const u64) {
    uint8_t* data = (uint8_t*)&u64;
    return ((uint64_t)data[7] << 0) | ((uint64_t)data[6] << 8)
        | ((uint64_t)data[5] << 16) | ((uint64_t)data[4] << 24)
        | ((uint64_t)data[3] << 32) | ((uint64_t)data[2] << 40)
        | ((uint64_t)data[1] << 48) | ((uint64_t)data[0] << 56);
}

#include "url.h"
#include "guid.h"
#include "http.h"
#include "hash.h"
#include "redis.h"
#include "mysql.h"
#include "pgsql.h"
#include "websocket.h"
#include "bitset.h"
