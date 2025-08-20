#pragma once

#include <cmath>
#include <time.h>

//i  - group，10位，(0~1023)
//g  - index，10位(0~1023)
//s  - 序号，13位(0~8912)
//ts - 时间戳，30位
//共63位，防止出现负数

namespace lcodec {

    const uint32_t GROUP_BITS   = 10;
    const uint32_t INDEX_BITS   = 10;
    const uint32_t SNUM_BITS    = 13;

    const uint32_t LETTER_LEN   = 12;
    const uint32_t LETTER_SIZE  = 62;

    //基准时钟：2022-10-01 08:00:00
    const uint32_t BASE_TIME    = 1664582400;

    const uint32_t MAX_GROUP    = ((1 << GROUP_BITS) - 1);   //1024 - 1
    const uint32_t MAX_INDEX    = ((1 << INDEX_BITS) - 1);   //1024 - 1
    const uint32_t MAX_SNUM     = ((1 << SNUM_BITS) - 1);    //8912 - 1

    //每一group独享一个id生成种子
    static time_t LAST_TIME = 0;
    static size_t SERIAL_INDEX_TABLE[(1 << GROUP_BITS)] = { 0 };

    static char LETTERS[] = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";

    static uint64_t guid_new(uint32_t group, uint32_t index){
        if (group == 0) {
            group = rand();
        }
        if (index == 0) {
            index = rand();
        }
        group %= MAX_GROUP;
        index %= MAX_INDEX;
        time_t now_time;
        time(&now_time);
        size_t serial_index = 0;
        if (now_time > LAST_TIME) {
            SERIAL_INDEX_TABLE[group] = 0;
            LAST_TIME = now_time;
        }
        else {
            serial_index = ++SERIAL_INDEX_TABLE[group];
            //种子溢出以后，时钟往前推
            if (serial_index >= MAX_SNUM) {
                SERIAL_INDEX_TABLE[group] = 0;
                LAST_TIME = ++now_time;
                serial_index = 0;
            }
        }
        return ((LAST_TIME - BASE_TIME) << (SNUM_BITS + GROUP_BITS + INDEX_BITS)) |
                (serial_index << (GROUP_BITS + INDEX_BITS)) | (index << GROUP_BITS) | group;
    }

    static int guid_string(lua_State* L, uint32_t group, uint32_t index) {
        char sguid[32];
        size_t guid = guid_new(group, index);
        snprintf(sguid, 32, "%zu", guid);
        lua_pushstring(L, sguid);
        return 1;
    }

    static int guid_hex(lua_State* L, uint32_t group, uint32_t index) {
        char sguid[32];
        size_t guid = guid_new(group, index);
        snprintf(sguid, 32, "%016zx", guid);
        lua_pushlstring(L, sguid, 16);
        return 1;
    }

    static int guid_tostring(lua_State* L, uint64_t guid) {
        char sguid[32];
        snprintf(sguid, 32, "%zu", guid);
        lua_pushstring(L, sguid);
        return 1;
    }

    static int guid_tohex(lua_State* L, uint64_t guid) {
        char sguid[32];
        snprintf(sguid, 32, "%016zx", guid);
        lua_pushlstring(L, sguid, 16);
        return 1;
    }

    static int guid_tobin(lua_State* L, uint64_t guid) {
        lua_pushlstring(L, (char*)&guid, 8);
        return 1;
    }

    static int guid_totrace(lua_State* L, uint64_t guid) {
        char bguid[16], hguid[64];
        uint64_t biged = std::byteswap(guid);
        *(uint64_t*)bguid = biged;
        *(uint64_t*)(bguid + 8) = biged;
        snprintf(hguid, 32, "%016zx", guid);
        snprintf(hguid + 16, 32, "%016zx", guid);
        lua_pushlstring(L, hguid, 32);
        lua_pushlstring(L, bguid, 16);
        return 2;
    }

    static uint64_t string_toguid(std::string guid) {
        return strtoull(guid.c_str(), nullptr, 10);
    }

    static uint64_t hex_toguid(std::string guid) {
        return strtoull(guid.c_str(), nullptr, 10);
    }

    static int guid_encode(lua_State* L) {
        char tmp[LETTER_LEN];
        memset(tmp, 0, LETTER_LEN);
        uint64_t val = (lua_gettop(L) > 0) ? lua_tointeger(L, 1) : guid_new(0, 0);
        for (uint32_t i = 0; i < LETTER_LEN - 1; ++i) {
            tmp[i] = LETTERS[val % LETTER_SIZE];
            val /= LETTER_SIZE;
            if (val == 0) break;
        }
        lua_pushstring(L, tmp);
        return 1;
    }

    static int find_index(char val) {
        if (val >= 97) return val - 61;
        if (val >= 65) return val - 55;
        return val - 48;
    }

    static uint64_t guid_decode(std::string sval){
        uint64_t val = 0;
        size_t len = sval.size();
        const char* cval = sval.c_str();
        for (size_t i = 0; i < len; ++i) {
            val += uint64_t(find_index(cval[i]) * pow(LETTER_SIZE, i));
        }
        return val;
    }

    size_t format_guid(lua_State* L) {
        if (lua_type(L, 1) == LUA_TSTRING) {
            char* chEnd = NULL;
            const char* sguid = lua_tostring(L, 1);
            return strtoull(sguid, &chEnd, 10);
        }
        else {
            return lua_tointeger(L, 1);
        }
    }

    static int guid_group(lua_State* L) {
        size_t guid = format_guid(L);
        lua_pushinteger(L, guid & 0x3ff);
        return 1;
    }

    static int guid_index(lua_State* L) {
        size_t guid = format_guid(L);
        lua_pushinteger(L, (guid >> GROUP_BITS) & 0x3ff);
        return 1;
    }

    static int guid_time(lua_State* L) {
        size_t guid = format_guid(L);
        size_t time = (guid >> (GROUP_BITS + INDEX_BITS + SNUM_BITS)) & 0x3fffffff;
        lua_pushinteger(L, time + BASE_TIME);
        return 1;
    }

    static int guid_source(lua_State* L) {
        size_t guid = format_guid(L);
        lua_pushinteger(L, guid & 0x3ff);
        lua_pushinteger(L, (guid >> GROUP_BITS) & 0x3ff);
        lua_pushinteger(L, ((guid >> (GROUP_BITS + INDEX_BITS + SNUM_BITS)) & 0x3fffffff) + BASE_TIME);
        return 3;
    }
}
