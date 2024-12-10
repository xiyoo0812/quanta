#pragma once

#include "lua_kit.h"
#include "smdb.h"

using namespace std;
using namespace luakit;

namespace lsmdb {

    class smdb_driver {
    public:
        smdb_driver() {}
        ~smdb_driver() { close(); }

        void close() {
            if (m_smdb) {
                m_smdb->close();
                delete m_smdb;
                m_smdb = nullptr;
            }
        }

        void set_codec(codec_base* codec) {
            m_jcodec = codec;
        }

        void flush() {
            if (m_smdb) m_smdb->flush();
        }

        smdb_code open(const char* path) {
            close();
            m_smdb = new smdb();
            auto code = m_smdb->open(path);
            if (m_smdb->is_error(code)) {
                m_smdb->close();
                delete m_smdb;
                return code;
            }
            return code;
        }

        smdb_code put(lua_State* L) {
            if (m_smdb) {
                auto key = read_key(L, 1);
                auto val = read_value(L, 2);
                return m_smdb->put(key, val);
            }
            return smdb_code::SMDB_DB_NOT_INIT;
        }

        bool del(lua_State* L) {
            if (!m_smdb) return false;
            auto key = read_key(L, 1);
            m_smdb->del(key);
            return true;
        }

        int get(lua_State* L) {
            if (m_smdb) {
                auto key = read_key(L, 1);
                auto val = m_smdb->get(key);
                if (val.size() > 0) {
                    push_value(L, val.data(), val.size());
                    return 1;
                }
            }
            return 0;
        }

        int first(lua_State* L) {
            if (m_smdb) {
                string_view key, val;
                if (m_smdb->first(key, val)) {
                    push_value(L, key.data(), key.size());
                    push_value(L, val.data(), val.size());
                    return 2;
                }
            }
            return 0;
        }

        int next(lua_State* L) {
            if (m_smdb) {
                string_view key, val;
                if (m_smdb->next(key, val)) {
                    push_value(L, key.data(), key.size());
                    push_value(L, val.data(), val.size());
                    return 2;
                }
            }
            return 0;
        }

    protected:
        string read_key(lua_State* L, int idx) {
            size_t len;
            int type = lua_type(L, idx);
            if (type == LUA_TNUMBER) {
                if (lua_isinteger(L, idx)) {
                    return to_string(lua_tointeger(L, idx));
                }
                return to_string(lua_tonumber(L, idx));
            }
            if (type != LUA_TSTRING) {
                luaL_error(L, "lsmdb read %d type %s not suppert!", idx, lua_typename(L, idx));
            }
            const char* buf = lua_tolstring(L, idx, &len);
            return string(buf, len);
        }

        string_view read_value(lua_State* L, int idx) {
            size_t len;
            int type = lua_type(L, idx);
            if (m_jcodec) {
                switch (type) {
                case LUA_TNIL:
                case LUA_TTABLE:
                case LUA_TNUMBER:
                case LUA_TSTRING:
                case LUA_TBOOLEAN: {
                    const char* buf = (const char*)m_jcodec->encode(L, idx, &len);
                    return string_view(buf, len);
                }
                default:
                    luaL_error(L, "lsmdb read %d type %s not suppert!", idx, lua_typename(L, idx));
                    break;
                }
            }
            if (type != LUA_TSTRING) {
                luaL_error(L, "lsmdb read %d type %s not suppert!", idx, lua_typename(L, idx));
            }
            const char* buf = lua_tolstring(L, idx, &len);
            return string_view(buf, len);
        }

        void push_value(lua_State* L, const char* buf, size_t len) {
            if (m_jcodec) {
                try {
                    m_jcodec->decode(L, (uint8_t*)buf, len);
                } catch (...) {
                    lua_pushlstring(L, buf, len);
                }
                return;
            }
            if (lua_stringtonumber(L, buf) == 0) {
                lua_pushlstring(L, buf, len);
            }
        }

    protected:
        smdb* m_smdb = nullptr;
        codec_base* m_jcodec = nullptr;
    };
}
