#pragma once

namespace lcodec {
    
    inline void hash(const char* str, int sz, char key[8]) {
        long djb_hash = 5381L;
        long js_hash = 1315423911L;
        for (int i = 0; i < sz; i++) {
            char c = (char)str[i];
            djb_hash += (djb_hash << 5) + c;
            js_hash ^= ((js_hash << 5) + c + (js_hash >> 2));
        }

        key[0] = djb_hash & 0xff;
        key[1] = (djb_hash >> 8) & 0xff;
        key[2] = (djb_hash >> 16) & 0xff;
        key[3] = (djb_hash >> 24) & 0xff;

        key[4] = js_hash & 0xff;
        key[5] = (js_hash >> 8) & 0xff;
        key[6] = (js_hash >> 16) & 0xff;
        key[7] = (js_hash >> 24) & 0xff;
    }

    static int hash_code(lua_State* L) {
        size_t hcode = 0;
        int type = lua_type(L, 1);
        if (type == LUA_TNUMBER) {
            hcode = std::hash<int64_t>{}(lua_tointeger(L, 1));
        } else if (type == LUA_TSTRING) {
            hcode = std::hash<std::string>{}(lua_tostring(L, 1));
        } else {
            luaL_error(L, "hashkey only support number or string!");
        }
        size_t mod = luaL_optinteger(L, 2, 0);
        if (mod > 0) {
            hcode = (hcode % mod) + 1;
        }
        lua_pushinteger(L, hcode);
        return 1;
    }

    static int lhashkey(lua_State* L) {
        size_t sz = 0;
        const char* key = luaL_checklstring(L, 1, &sz);
        char realkey[8];
        hash(key, (int)sz, realkey);
        lua_pushlstring(L, (const char*)realkey, 8);
        return 1;
    }

}
