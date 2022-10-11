#pragma once
#include "buffer.h"

using namespace std;
using namespace lcodec;
using namespace luakit;

//https://bsonspec.org/spec.html
namespace lmongo {
    const uint8_t   max_bson_depth  = 64;
    const uint32_t  max_bson_index = 1024;

    static char bson_numstrs[max_bson_index][4];
    static int bson_numstr_len[max_bson_index];

    enum class bson_type : uint8_t {
        BSON_EOO        = 0,
        BSON_REAL       = 1,
        BSON_STRING     = 2,
        BSON_DOCUMENT   = 3,
        BSON_ARRAY      = 4,
        BSON_BINARY     = 5,
        BSON_UNDEFINED  = 6,    //Deprecated
        BSON_OBJECTID   = 7,
        BSON_BOOLEAN    = 8,
        BSON_DATE       = 9,
        BSON_NULL       = 10,
        BSON_REGEX      = 11,
        BSON_DBPOINTER  = 12,   //Deprecated
        BSON_JSCODE     = 13,
        BSON_SYMBOL     = 14,   //Deprecated
        BSON_CODEWS     = 15,   //Deprecated
        BSON_INT32      = 16,
        BSON_TIMESTAMP  = 17,
        BSON_INT64      = 18,
        BSON_INT128     = 19,
        BSON_MINKEY     = 255,
        BSON_MAXKEY     = 127,
    };

    class bson_value {
    public:
        int64_t val = 0;
        string str = "";
        string opt = "";
        uint8_t stype = 0;
        bson_type type = bson_type::BSON_EOO;
        bson_value(bson_type t, string s, uint8_t st = 0) : type(t), str(s), stype(st) {}
        bson_value(bson_type t, int64_t i, uint8_t st = 0) : type(t), val(i), stype(st) {}
        bson_value(bson_type t, string s, string o, uint8_t st = 0) : type(t), str(s), opt(s), stype(st) {}
    };

    class bson {
    public:
        slice* encode_slice(lua_State* L) {
            lua_settop(L, 1);
            luaL_checktype(L, 1, LUA_TTABLE);
            m_buffer.reset();
            pack_dict(L, 0);
            return m_buffer.get_slice();
        }

         int encode(lua_State* L) {
            size_t data_len = 0;
            slice* buf = encode_slice(L);
            const char* data = (const char*)buf->data(&data_len);
            lua_pushlstring(L, data, data_len);
            lua_pushinteger(L, data_len);
            return 2;
        }

        int decode_slice(lua_State* L, slice* buf) {
            lua_settop(L, 0);
            unpack_dict(L, buf, false);
            return lua_gettop(L);
        }

        int decode(lua_State* L, const char* buf, size_t len) {
            m_buffer.reset();
            m_buffer.push_data((uint8_t*)buf, len);
            return decode_slice(L, m_buffer.get_slice());
        }

        slice* encode_order_slice(lua_State* L) {
            int n = lua_gettop(L);
            if (n < 2 || n % 2 != 0) {
                luaL_error(L, "Invalid ordered dict");
            }
            size_t sz;
            m_buffer.reset();
            size_t offset = m_buffer.size();
            m_buffer.write<uint32_t>(0);
            for (int i = 0; i < n; i += 2) {
                int vt = lua_type(L, i + 2);
                if (vt != LUA_TNIL && vt != LUA_TNONE) {
                    const char* key = lua_tolstring(L, i + 1, &sz);
                    if (key == nullptr) {
                        luaL_error(L, "Argument %d need a string", i + 1);
                    }
                    lua_pushvalue(L, i + 2);
                    pack_one(L, key, sz, 0);
                    lua_pop(L, 1);
                }
            }
            m_buffer.write<uint8_t>(0);
            uint32_t size = m_buffer.size() - offset;
            m_buffer.copy(offset, (uint8_t*)&size, sizeof(uint32_t));
            return m_buffer.get_slice();
        }
        
        int encode_order(lua_State* L) {            
            size_t data_len = 0;
            slice* buf = encode_order_slice(L);
            const char* data = (const char*)buf->data(&data_len);
            lua_pushlstring(L, data, data_len);
            lua_pushinteger(L, data_len);
            return 2;
        }

    protected:
        size_t bson_index(char* str, size_t i) {
            if (i < max_bson_index) {
                memcpy(str, bson_numstrs[i], 4);
                return bson_numstr_len[i];
            }
            return sprintf(str, "%zd", i);
        }

        void write_binary(bson_value* value) {
            m_buffer.write<uint32_t>(value->str.size() + 1);
            m_buffer.write<uint8_t>(value->stype);
            m_buffer.write(value->str.c_str(), value->str.size());
        }

        void write_cstring(const char* buf, size_t len) {
            m_buffer.write(buf, len);
            m_buffer.write<char>('\0');
        }

        void write_string(const char* buf, size_t len) {
            m_buffer.write<uint32_t>(len + 1);
            write_cstring(buf, len);
        }

        void write_key(bson_type type, const char* key, size_t len) {
            m_buffer.write<uint8_t>((uint8_t)type);
            write_cstring(key, len);
        }

        template<typename T>
        void write_pair(bson_type type, const char* key, size_t len, T value) {
            write_key(type, key, len);
            m_buffer.write(value);
        }

        void write_number(lua_State *L, const char* key, size_t len) {
            if (lua_isinteger(L, -1)) {
                int64_t v = lua_tointeger(L, -1);
                if (v >= INT32_MIN && v <= INT32_MAX) {
                    write_pair<int32_t>(bson_type::BSON_INT32, key, len, v);
                } else {
                    write_pair<int64_t>(bson_type::BSON_INT64, key, len, v);
                }
            } else {
                write_pair<double>(bson_type::BSON_REAL, key, len, lua_tonumber(L, -1));
            }
        }

        void pack_array(lua_State *L, int depth, size_t len) {
            // length占位
            size_t offset = m_buffer.size();
            m_buffer.write<uint32_t>(0);
            for (size_t i = 1; i <= len; i++) {
                char numkey[32];
                lua_geti(L, -1, i);
                size_t len = bson_index(numkey, i - 1);
                pack_one(L, numkey, len, depth);
                lua_pop(L, 1);
            }
            m_buffer.write<uint8_t>(0);
            uint32_t size = m_buffer.size() - offset;
            m_buffer.copy(offset, (uint8_t*)&size, sizeof(uint32_t));
        }

        bson_type check_doctype(lua_State *L) {
            lua_pushnil(L);
            if (lua_next(L, -2) == 0) {
                return bson_type::BSON_DOCUMENT;
            }
            auto t = lua_isinteger(L, -2) ? bson_type::BSON_ARRAY : bson_type::BSON_DOCUMENT;;
            lua_pop(L, 2);
            return t;
        }

        void pack_table(lua_State *L, const char* key, size_t len, int depth) {
            if (depth > max_bson_depth) {
                luaL_error(L, "Too depth while encoding bson");
            }
            bson_type type = check_doctype(L);
            write_key(type, key, len);
            if (type == bson_type::BSON_ARRAY) {
                pack_array(L, depth, lua_rawlen(L, -1));
            } else {
                pack_dict(L, depth);
            }
        }

        void pack_bson_value(lua_State* L, bson_value* value){
            switch(value->type) {
            case bson_type::BSON_MINKEY:
            case bson_type::BSON_MAXKEY:
            case bson_type::BSON_NULL:
                break;
            case bson_type::BSON_BINARY:
                write_binary(value);
                break;
            case bson_type::BSON_INT32:
                m_buffer.write<int32_t>(value->val);
                break;
            case bson_type::BSON_DATE:
            case bson_type::BSON_INT64:
            case bson_type::BSON_TIMESTAMP:
                m_buffer.write<int64_t>(value->val);
                break;
            case bson_type::BSON_OBJECTID:
            case bson_type::BSON_JSCODE:
                m_buffer.write(value->str.c_str(), value->str.size());
                break;
            case bson_type::BSON_REGEX:
                write_cstring(value->str.c_str(), value->str.size());
                write_cstring(value->opt.c_str(), value->opt.size());
                break;
            default:
                luaL_error(L, "Invalid value type : %d", (int)value->type);
            }
        }

        void pack_one(lua_State *L, const char* key, size_t len, int depth) {
            int vt = lua_type(L, -1);
            switch(vt) {
            case LUA_TNUMBER:
                write_number(L, key, len);
                break;
            case LUA_TBOOLEAN:
                write_pair<bool>(bson_type::BSON_BOOLEAN, key, len, lua_toboolean(L, -1));
                break;
            case LUA_TTABLE:{
                    bson_value* value = lua_to_object<bson_value*>(L, -1);
                    if (value){
                        write_key(value->type, key, len);
                        pack_bson_value(L, value);
                    } else {
                        pack_table(L, key, len, depth + 1);
                    }
                }
                break;
            case LUA_TSTRING: {
                    size_t sz;
                    const char* buf = lua_tolstring(L, -1, &sz);
                    write_key(bson_type::BSON_STRING, key, len);
                    write_string(buf, sz);
                }
                break;
            case LUA_TNIL:
                luaL_error(L, "Bson array has a hole (nil), Use bson.null instead");
            default:
                luaL_error(L, "Invalid value type : %s", lua_typename(L,vt));
            }
        }

        void pack_dict_data(lua_State *L, int depth, int kt) {
            if (kt == LUA_TNUMBER) {
                luaL_error(L, "Bson dictionary's key can't be number");
            }
            if (kt != LUA_TSTRING) {
                luaL_error(L, "Invalid key type : %s", lua_typename(L, kt));
            }
            size_t sz;
            const char* buf = lua_tolstring(L, -2, &sz);
            pack_one(L, buf, sz, depth);
        }

        void pack_dict(lua_State *L, int depth) {
            // length占位
            size_t offset = m_buffer.size();
            m_buffer.write<uint32_t>(0);
            lua_pushnil(L);
            while(lua_next(L, -2) != 0) {
                pack_dict_data(L, depth, lua_type(L, -2));
                lua_pop(L, 1);
            }
            m_buffer.write<uint8_t>(0);
            uint32_t size = m_buffer.size() - offset;
            m_buffer.copy(offset, (uint8_t*)&size, sizeof(uint32_t));
        }

        template<typename T>
        T read_val(lua_State* L, slice* buff) {
            T value;
            if (buff->pop((uint8_t*)&value, sizeof(T)) == 0) {
                luaL_error(L, "decode can't unpack one value");
            }
            return value;
        }

        const char* read_bytes(lua_State* L, slice* buf, size_t sz) {
            const char* dst = (const char*)buf->peek(sz);
            if (!dst) {
                luaL_error(L, "Invalid bson string , length = %d", sz);
            }
            buf->erase(sz);
            return dst;
        }

        const char* read_string(lua_State* L, slice* buf, size_t& sz) {
            sz = (size_t)read_val<uint32_t>(L, buf);
            if (sz <= 0) {
                luaL_error(L, "Invalid bson string , length = %d", sz);
            }
            sz = sz - 1;
            const char* dst = "";
            if (sz > 0) {
                dst = read_bytes(L, buf, sz);
            }
            buf->erase(1);
            return dst;
        }

        const char* read_cstring(lua_State * L, slice * buf, size_t& l) {
            size_t sz;
            const char* dst = (const char*)buf->data(&sz);
            for (l = 0; l < sz; ++l) {
                if (l == sz - 1) {
                    luaL_error(L, "Invalid bson block : cstring");
                }
                if (dst[l] == '\0') {
                    buf->erase(l + 1);
                    return dst;
                }
            }
            luaL_error(L, "Invalid bson block : cstring");
            return "";
        }

        void unpack_dict(lua_State* L, slice* buf, bool isarray) {
            uint32_t sz = read_val<uint32_t>(L, buf);
            if (buf->size() < sz - 4) {
                luaL_error(L, "decode can't unpack one value");
            }
            lua_newtable(L);
            while (!buf->empty()) {
                size_t klen = 0;
                bson_type bt = (bson_type)read_val<uint8_t>(L, buf);
                if (bt == bson_type::BSON_EOO) break;
                const char* key = read_cstring(L, buf, klen);
                if (isarray) {
                    lua_pushinteger(L, strtol(key, nullptr, 10) + 1);
                }
                else {
                    lua_pushlstring(L, key, klen);
                }
                switch (bt) {
                case bson_type::BSON_REAL:
                    lua_pushnumber(L, read_val<double>(L, buf));
                    break;
                case bson_type::BSON_BOOLEAN:
                    lua_pushboolean(L, read_val<bool>(L, buf));
                    break;
                case bson_type::BSON_INT32:
                    lua_pushinteger(L, read_val<int32_t>(L, buf));
                    break;
                case bson_type::BSON_INT64:
                    lua_pushinteger(L, read_val<int64_t>(L, buf));
                    break;
                case bson_type::BSON_JSCODE:
                    lua_push_object(L, new bson_value(bt, read_string(L, buf, klen)));
                    break;
                case bson_type::BSON_STRING:{
                        const char* s = read_string(L, buf, klen);
                        lua_pushlstring(L, s, klen);
                    }
                    break;
                case bson_type::BSON_REGEX:
                    lua_push_object(L, new bson_value(bt, read_cstring(L, buf, klen), read_cstring(L, buf, klen)));
                    break;
                case bson_type::BSON_DOCUMENT:
                    unpack_dict(L, buf, false);
                    break;
                case bson_type::BSON_ARRAY:
                    unpack_dict(L, buf, true);
                    break;
                case bson_type::BSON_OBJECTID:
                    lua_push_object(L, new bson_value(bt, read_bytes(L, buf, 12)));
                    break;
                case bson_type::BSON_DATE:
                case bson_type::BSON_TIMESTAMP:
                    lua_push_object(L, new bson_value(bt, read_val<int64_t>(L, buf)));
                    break;
                case bson_type::BSON_MINKEY:
                case bson_type::BSON_MAXKEY:
                case bson_type::BSON_NULL:
                    lua_push_object(L, new bson_value(bt, 0));
                    break;
                case bson_type::BSON_BINARY: {
                        uint32_t sz = read_val<uint32_t>(L, buf);
                        uint8_t subtype = read_val<uint8_t>(L, buf);
                        lua_push_object(L, new bson_value(bt, read_bytes(L, buf, sz), subtype));
                    }
                    break;
                default:
                    luaL_error(L, "Invalid bson type : %d", bt);
                }
                lua_rawset(L, -3);
            }
        }
    private:
        var_buffer m_buffer;
    };
}