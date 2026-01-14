#pragma once

#include "lua_base.h"

namespace luakit {

    static bool lua_string_starts_with(lua_State* L, vstring str, vstring with) {
        return str.starts_with(with);
    }

    static bool lua_string_ends_with(lua_State* L, vstring str, vstring with) {
        return str.ends_with(with);
    }

    static sstring lua_string_title(sstring str) {
        if (!str.empty()) str[0] = std::toupper(static_cast<unsigned char>(str[0]));
        return str;
    }

    static sstring lua_string_untitle(sstring str) {
        if (!str.empty()) str[0] = std::tolower(static_cast<unsigned char>(str[0]));
        return str;
    }

    static int lua_string_split(lua_State* L, vstring str, vstring delim) {
        size_t step = delim.size();
        if (step == 0) luaL_error(L, "delimiter cannot be empty");
        size_t cur = 0, len = 0;
        size_t pos = str.find(delim);
        bool pack = luaL_opt(L, lua_toboolean, 3, true);
        if (pack) lua_createtable(L, 8, 0);
        while (pos != vstring::npos) {
            lua_pushlstring(L, str.data() + cur, pos - cur);
            if (pack) lua_rawseti(L, -2, ++len);
            cur = pos + step;
            pos = str.find(delim, cur);
        }
        if (str.size() > cur) {
            lua_pushlstring(L, str.data() + cur, str.size() - cur);
            if (pack) lua_rawseti(L, -2, ++len);
        }
        return (pack) ? 1 : (int)len;
    }

    static bool is_lua_array(lua_State* L, int index, bool emy_as_arr = false) {
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

    static void copy_table(lua_State* L, int src_idx, int dst_idx) {
        src_idx = lua_absindex(L, src_idx);
        dst_idx = lua_absindex(L, dst_idx);
        lua_pushnil(L);
        while (lua_next(L, src_idx) != 0) {
            if (lua_istable(L, -1)) {
                lua_pushvalue(L, -2);   //key
                lua_pushvalue(L, -1);
                lua_rawget(L, dst_idx);
                if (!lua_istable(L, -1)) {
                    lua_pop(L, 1);
                    lua_createtable(L, 0, 8);
                }
                copy_table(L, -3, -1);
                lua_rawset(L, dst_idx);
            }
            else {
                lua_pushvalue(L, -2);
                lua_pushvalue(L, -2);
                lua_rawset(L, dst_idx);
            }
            lua_pop(L, 1);
        }
    }

    static int lua_table_deepcopy(lua_State* L) {
        if (!lua_istable(L, 2)) {
            lua_settop(L, 1);
            lua_createtable(L, 0, 8);
        }
        if (lua_istable(L, 1)) {
            copy_table(L, 1, 2);
        }
        return 1;
    }

    static int lua_table_copy(lua_State* L) {
        if (!lua_istable(L, 2)) {
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
        }
        return 1;
    }

    static int lua_table_clean(lua_State* L) {
        if (lua_istable(L, 1)) {
            lua_pushnil(L);
            while (lua_next(L, 1) != 0) {
                lua_pushvalue(L, -2);
                lua_pushnil(L);
                lua_rawset(L, 1);
                lua_pop(L, 1);
            }
        }
        return 0;
    }

    static int lua_table_size(lua_State* L) {
        uint32_t len = 0;
        if (lua_istable(L, 1)) {
            lua_pushnil(L);
            while (lua_next(L, 1) != 0) {
                lua_pop(L, 1);
                len++;
            }
        }
        lua_pushinteger(L, len);
        return 1;
    }

    static int lua_table_keys(lua_State* L) {
        lua_createtable(L, 8, 0);
        if (lua_istable(L, 1)) {
            int i = 0;
            lua_pushnil(L);
            while (lua_next(L, 1) != 0) {
                lua_pushvalue(L, -2);
                lua_rawseti(L, 2, ++i);
                lua_pop(L, 1);
            }
        }
        return 1;
    }

    static int lua_table_vals(lua_State* L) {
        lua_createtable(L, 8, 0);
        if (lua_istable(L, 1)) {
            int i = 0;
            lua_pushnil(L);
            while (lua_next(L, 1) != 0) {
                lua_pushvalue(L, -1);
                lua_rawseti(L, 2, ++i);
                lua_pop(L, 1);
            }
        }
        return 1;
    }

    static int lua_table_kvals(lua_State* L) {
        lua_createtable(L, 8, 0);
        if (lua_istable(L, 1)) {
            int i = 0;
            lua_pushnil(L);
            while (lua_next(L, 1) != 0) {
                lua_pushvalue(L, -2);
                lua_rawseti(L, 2, ++i);
                lua_pushvalue(L, -1);
                lua_rawseti(L, 2, ++i);
                lua_pop(L, 1);
            }
        }
        return 1;
    }

    static int lua_table_pushback(lua_State* L) {
        int argn = 0;
        if (lua_istable(L, 1)) {
            argn = lua_gettop(L) - 1;
            size_t src_len = lua_rawlen(L, 1);
            for (int i = 0; i < argn; i++) {
                lua_pushvalue(L, i + 2);
                lua_rawseti(L, 1, ++src_len);
            }
        }
        lua_pushinteger(L, argn);
        return 1;
    }

    static int lua_table_join(lua_State* L) {
        if (lua_istable(L, 1) && lua_istable(L, 2)) {
            size_t src_len = lua_rawlen(L, 1);
            size_t dst_len = lua_rawlen(L, 2);
            for (size_t i = 0; i < src_len; i++) {
                lua_rawgeti(L, 1, i + 1);
                lua_rawseti(L, 2, ++dst_len);
            }
        }
        return 1;
    }

    static int lua_table_indexof(lua_State* L) {
        if (lua_istable(L, 1)) {
            lua_pushnil(L);
            while (lua_next(L, 1) != 0) {
                if (lua_rawequal(L, -1, 2)) {
                    lua_pop(L, 1);
                    return 1;
                }
                lua_pop(L, 1);
            }
        }
        return 0;
    }

    static int lua_table_erase(lua_State* L) {
        size_t deleted_count = 0;
        if (lua_istable(L, 1)) {
            size_t write_index = 1;
            size_t size = lua_rawlen(L, 1);
            bool once = lua_toboolean(L, 3);
            for (size_t read_index = 1; read_index <= size; read_index++) {
                lua_rawgeti(L, 1, read_index);
                if (lua_rawequal(L, -1, 2) && (!once || deleted_count == 0)) {
                    deleted_count++;
                    lua_pop(L, 1);
                } else {
                    if (read_index != write_index) {
                        lua_rawseti(L, 1, write_index);
                    } else {
                        lua_pop(L, 1);
                    }
                    write_index++;
                }
            }
            for (size_t i = write_index; i <= size; i++) {
                lua_pushnil(L);
                lua_seti(L, 1, i);
            }
            lua_pushinteger(L, deleted_count);
            return 1;
        }
        return 0;
    }

    static int lua_table_slice(lua_State* L) {
        if (lua_istable(L, 1)) {
            size_t spos = luaL_optinteger(L, 2, 0);
            size_t epos = luaL_optinteger(L, 3, 0);
            if (epos == 0) epos = lua_rawlen(L, 1);
            int64_t len = epos - spos;
            if (len >= 0) {
                lua_createtable(L, len, 0);
                for (int64_t i = 0; i <= len; i++) {
                    lua_rawgeti(L, 1, spos + i);
                    lua_rawseti(L, -2, i + 1);
                }
                return 1;
            }
        }
        return 0;
    }
}
