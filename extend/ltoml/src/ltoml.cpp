#define LUA_LIB

#include "lua_kit.h"
#include "toml.hpp"

using namespace std;
using namespace luakit;

namespace ltoml {

    inline void decode_node(lua_State* L, toml::node* node);
    inline void decode_key(lua_State* L, const toml::key* key) {
        const char* value = key->data();
        if (lua_stringtonumber(L, value) == 0) {
            lua_pushlstring(L, value, key->length());
        }
    }

    inline void decode_array(lua_State* L, toml::array* arr) {
        size_t idx = 1;
        lua_createtable(L, 0, 4);
        arr->for_each([&](toml::node& node) {
            decode_node(L, &node);
            lua_seti(L, -2, idx++);
        });
    }

    inline void decode_table(lua_State* L, toml::table* tbl) {
        lua_createtable(L, 0, 4);
        tbl->for_each([&](const toml::key& key, auto&& node) {
            decode_key(L, &key);
            decode_node(L, &node);
            lua_settable(L, -3);
        });
    }

    inline void decode_node(lua_State* L, toml::node* node) {
        if (node->is_table()) {
            decode_table(L, node->as_table());
        } else if (node->is_array()) {
            decode_array(L, node->as_array());
        } else if (node->is_boolean()) {
            lua_pushboolean(L, node->ref<bool>());
        } else if (node->is_integer()) {
            lua_pushinteger(L, node->ref<int64_t>());
        } else if (node->is_floating_point()) {
            lua_pushnumber(L, node->ref<double>());
        } else if (node->is_string()) {
            auto value = node->ref<string>();
            lua_pushlstring(L, value.c_str(), value.length());
        } else {
            stringstream stm;
            stm << node;
            lua_pushlstring(L, stm.str().c_str(), stm.str().length());
        }
    }

    inline int decode_toml(lua_State* L, string_view doc) {
        try {
            toml::table tbl = toml::parse(doc);
            decode_table(L, &tbl);
            return 1;
        } catch (const toml::parse_error& err) {
            luaL_error(L, err.what());
        }
        return 0;
    }

    inline toml::table encode_table(lua_State* L, int index);
    inline toml::array encode_array(lua_State* L, int index) {
        toml::array array;
        int raw_len = lua_rawlen(L, index);
        for (int i = 1; i <= raw_len; ++i) {
            lua_rawgeti(L, index, i);
            switch (lua_type(L, -1)) {
            case LUA_TBOOLEAN:
                array.push_back(toml::value<bool>(lua_toboolean(L, -1)));
                break;
            case LUA_TSTRING: {
                size_t len;
                const char* sstr = lua_tolstring(L, -1, &len);
                array.push_back(toml::value<string>(string(sstr, len)));
                break;
            }
            case LUA_TNUMBER: {
                if (lua_isinteger(L, -1)) {
                    array.push_back(toml::value<int64_t>(lua_tointeger(L, -1)));
                } else {
                    array.push_back(toml::value<int64_t>(lua_tonumber(L, -1)));
                }
                break;
            }
            case LUA_TTABLE: {
                if (is_lua_array(L, -1)) {
                    array.push_back(encode_array(L, -1));
                } else {
                    array.push_back(encode_table(L, lua_absindex(L, -1)));
                }
                break;
            }
            }
            lua_pop(L, 1);
        }
        return array;
    }

    inline toml::key encode_key(lua_State* L, int index) {
        switch (lua_type(L, index)) {
        case LUA_TNUMBER:
        case LUA_TSTRING:
            return toml::key(lua_tostring(L, index));
        }
        luaL_error(L, "unsuppert lua type");
        return {};
    }

    inline toml::table encode_table(lua_State* L, int index) {
        toml::table tbl;
        lua_pushnil(L);
        while (lua_next(L, index) != 0) {
            toml::key key = encode_key(L, -2);
            switch (lua_type(L, -1)) {
                case LUA_TBOOLEAN:
                    tbl.insert(key, toml::value<bool>(lua_toboolean(L, -1)));
                    break;
                case LUA_TSTRING: {
                    size_t len;
                    const char* sstr = lua_tolstring(L, -1, &len);
                    tbl.insert(key, toml::value<string>(string(sstr, len)));
                    break;
                }
                case LUA_TNUMBER: {
                    if (lua_isinteger(L, -1)) {
                        tbl.insert(key, toml::value<int64_t>(lua_tointeger(L, -1)));
                    } else {
                        tbl.insert(key, toml::value<int64_t>(lua_tonumber(L, -1)));
                    }
                    break;
                }
                case LUA_TTABLE:{
                    if (is_lua_array(L, -1)) {
                        tbl.insert(key, encode_array(L, -1));
                    } else {
                        tbl.insert(key, encode_table(L, lua_absindex(L, -1)));
                    }
                    break;
                }
            }
            lua_pop(L, 1);
        }
        return tbl;
    }

    inline int encode_toml(lua_State* L) {
        toml::table tbl = encode_table(L, 1);
        stringstream stm;
        stm << tbl;
        lua_pushlstring(L, stm.str().c_str(), stm.str().length());
        return 1;
    }

    inline int open_toml(lua_State* L, const char* tomlfile) {
        try {
            toml::table tbl = toml::parse_file(tomlfile);
            decode_table(L, &tbl);
            return 1;
        }
        catch (const toml::parse_error& err) {
            luaL_error(L, err.what());
        }
        return 0;
    }

    static int save_toml(lua_State* L, const char* tomlfile) {
        toml::table tbl = encode_table(L, 2);
        ofstream fstm(tomlfile);
        fstm << tbl;
        fstm.flush();
        fstm.close();
        lua_pushboolean(L, true);
        return 1;
    }

    lua_table open_ltoml(lua_State* L) {
        kit_state kit_state(L);
        lua_table toml = kit_state.new_table("toml");
        toml.set_function("decode", decode_toml);
        toml.set_function("encode", encode_toml);
        toml.set_function("open", open_toml);
        toml.set_function("save", save_toml);
        return toml;
    }
}

extern "C" {
    LUALIB_API int luaopen_ltoml(lua_State* L) {
        auto yaml = ltoml::open_ltoml(L);
        return yaml.push_stack();
    }
}
