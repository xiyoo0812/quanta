#pragma once

#include "lua_base.h"

namespace luakit {

    inline bool lua_string_starts_with(lua_State* L, std::string_view str, std::string_view with) {
        return str.starts_with(with);
    }

    inline bool lua_string_ends_with(lua_State* L, std::string_view str, std::string_view with) {
        return str.ends_with(with);
    }

    inline char* lua_string_title(char* str) {
        if (str && *str) *str = std::toupper(static_cast<unsigned char>(*str));
        return str;
    }

    inline char* lua_string_untitle(char* str) {
        if (str && *str) *str = std::tolower(static_cast<unsigned char>(*str));
        return str;
    }

    inline int lua_string_split(lua_State* L, std::string_view str, std::string_view delim) {
        size_t step = delim.size();
        if (step == 0) luaL_error(L, "delimiter cannot be empty");
        size_t cur = 0, len = 0;
        size_t pos = str.find(delim);
        bool pack = luaL_opt(L, lua_toboolean, 3, true);
        if (pack) lua_createtable(L, 8, 0);
        while (pos != std::string_view::npos) {
            lua_pushlstring(L, str.data() + cur, pos - cur);
            if (pack) lua_seti(L, -2, ++len);
            cur = pos + step;
            pos = str.find(delim, cur);
        }
        if (str.size() > cur) {
            lua_pushlstring(L, str.data() + cur, str.size() - cur);
            if (pack) lua_seti(L, -2, ++len);
        }
        return (pack) ? 1 : (int)len;
    }

    inline bool is_lua_array(lua_State* L, int index, bool emy_as_arr = false) {
        if (lua_type(L, index) != LUA_TTABLE) return false;
        size_t raw_len = lua_rawlen(L, index);
        if (raw_len == 0 && !emy_as_arr) return false;
        index = lua_absindex(L, index);
        lua_guard g(L);
        lua_pushnil(L);
        size_t curlen = 0;
        while (lua_next(L, index) != 0) {
            if (!lua_isinteger(L, -2)) return false;
            size_t key = lua_tointeger(L, -2);
            if (key <= 0 || key > raw_len) return false;
            lua_pop(L, 1);
            curlen++;
        }
        return curlen == raw_len;
    }
    
    static void copy_table(lua_State *L, int src_idx, int dst_idx) {
        lua_pushnil(L);
        while (lua_next(L, src_idx) != 0) {
            if (lua_istable(L, -1)) {
                lua_createtable(L, 0, 8);
                copy_table(L, lua_gettop(L) - 1, lua_gettop(L));
                lua_rawset(L, dst_idx);
            } else {
                lua_pushvalue(L, -2);
                lua_pushvalue(L, -2);
                lua_rawset(L, dst_idx);
            }
            lua_pop(L, 1);
        }
    }

    inline int lua_table_deepcopy(lua_State* L) {
        if (!lua_istable(L, 2)){
            lua_settop(L, 1);
            lua_createtable(L, 0, 8);
        }
        if (lua_istable(L, 1)) {
            copy_table(L, 1, 2);
        }
        return 1;
    }

    inline int lua_table_copy(lua_State* L) {
        if (!lua_istable(L, 2)){
            lua_settop(L, 1);
            lua_createtable(L, 0, 8);
        }
        if (lua_istable(L, 1)) {
            lua_pushnil(L);
            while (lua_next(L, 1) != 0) {
                lua_pushvalue(L, -2);
                lua_pushvalue(L, -2);
                lua_rawset(L, 2);
                lua_pop(L, 1);
            }
            lua_pop(L, 1);
        }
        return 1;
    }

    inline int lua_table_clean(lua_State* L) {
        if (lua_istable(L, 1)) {
            lua_pushnil(L);
            while (lua_next(L, 1) != 0) {
                lua_pushvalue(L, -2);
                lua_pushnil(L);
                lua_rawset(L, 1);
                lua_pop(L, 1);
            }
            lua_pop(L, 1);
        }
        return 0;
    }
}
