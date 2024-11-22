#pragma once

#include "unqlite.h"
#include "lua_kit.h"

using namespace std;
using namespace luakit;

namespace lunqlite {
    const uint32_t  max_jsonbuf_size = 1024 * 1024; //1M

    class unqlite_driver {
    public:
        unqlite_driver() {}
        ~unqlite_driver() { close(); }

        void close() {
            if (m_ucur) unqlite_kv_cursor_release(m_udb, m_ucur);
            if (m_udb) unqlite_close(m_udb);
            m_ucur = nullptr;
            m_udb = nullptr;
        }

        void set_codec(codec_base* codec) {
            m_jcodec = codec;
        }

        int open(lua_State* L, const char* path, int mode) {
            close();
            int rc = unqlite_open(&m_udb, path, UNQLITE_OPEN_CREATE);
            if (rc != UNQLITE_OK) return handler_err(L, rc);
            rc = unqlite_kv_cursor_init(m_udb, &m_ucur);
            return handler_err(L, rc);
        }

        int begin(lua_State* L) {
            int rc = unqlite_begin(m_udb);
            return handler_err(L, rc);
        }

        int commit(lua_State* L) {
            int rc = unqlite_commit(m_udb);
            return handler_err(L, rc);
        }

        int rollback(lua_State* L) {
            int rc = unqlite_rollback(m_udb);
            return handler_err(L, rc);
        }

        int put(lua_State* L) {
            size_t klen, vlen;
            const char* key = read_key(L, 1, &klen);
            const char* val = read_value(L, 2, &vlen);
            int rc = unqlite_kv_store(m_udb, key, klen, val, vlen);
            return handler_err(L, rc);
        }

        int del(lua_State* L) {
            size_t klen;
            const char* key = read_key(L, 1, &klen);
            int rc = unqlite_kv_delete(m_udb, key, klen);
            return handler_err(L, rc);
        }

        int get(lua_State* L) {
            size_t klen;
            unqlite_int64 blen = max_jsonbuf_size;
            const char* key = read_key(L, 1, &klen);
            int rc = unqlite_kv_fetch(m_udb, key, klen, m_buf, &blen);
            if (rc != UNQLITE_OK) {
                lua_pushnil(L);
                return handler_err(L, rc) + 1;
            }
            push_value(L, blen);
            lua_pushinteger(L, rc);
            return 2;
        }
      
        int cursor_seek(lua_State* L) {
            size_t klen;
            const char* key = luaL_tolstring(L, 1, &klen);
            int rc = unqlite_kv_cursor_seek(m_ucur, key, klen, 0);
            if (rc != UNQLITE_OK) return handler_err(L, rc);
            return handler_cursor_valid(L);
        }
        int cursor_first(lua_State* L) {
            int rc = unqlite_kv_cursor_first_entry(m_ucur);
            if (rc != UNQLITE_OK) return handler_err(L, rc);
            return handler_cursor_valid(L);
        }
        int cursor_last(lua_State* L) {
            int rc = unqlite_kv_cursor_last_entry(m_ucur);
            if (rc != UNQLITE_OK) return handler_err(L, rc);
            return handler_cursor_valid(L);
        }
        int cursor_next(lua_State* L) {
            int rc = unqlite_kv_cursor_next_entry(m_ucur);
            if (rc != UNQLITE_OK) return handler_err(L, rc);
            return handler_cursor_valid(L);
        }
        int cursor_prev(lua_State* L) {
            int rc = unqlite_kv_cursor_prev_entry(m_ucur);
            if (rc != UNQLITE_OK) return handler_err(L, rc);
            return handler_cursor_valid(L);
        }
        int cursor_close(lua_State* L) {
            int rc = unqlite_kv_cursor_delete_entry(m_ucur);
            return handler_err(L, rc);
        }

    protected:
        int handler_cursor_valid(lua_State* L) {
            int rc = unqlite_kv_cursor_valid_entry(m_ucur);
            lua_pushinteger(L, rc);
            if (rc) {
                lua_pushinteger(L, rc);
                int dlen; unqlite_int64 blen;
                unqlite_kv_cursor_key(m_ucur, m_buf, &dlen);
                push_value(L, dlen);
                unqlite_kv_cursor_data(m_ucur, m_buf, &blen);
                push_value(L, blen);
                return 3;
            }
            return 1;
        }
        int handler_err(lua_State* L, int rc) {
            int len = 0;
            const char* err;
            lua_pushinteger(L, rc);
            if (rc != UNQLITE_OK) {
                unqlite_config(m_udb, UNQLITE_CONFIG_ERR_LOG, &err, &len);
                if (len > 0) {
                    lua_pushlstring(L, err, len);
                    return 2;
                }
            }
            return 1;
        }

        const char* read_key(lua_State* L, int idx, size_t* len) {
            int type = lua_type(L, idx);
            if (m_jcodec) {
                switch (type) {
                case LUA_TNUMBER:
                    return (const char*)m_jcodec->encode(L, idx, len);
                case LUA_TSTRING:
                    return lua_tolstring(L, idx, len);
                default:
                    luaL_error(L, "lunqlite read key type %s not suppert!", lua_typename(L, idx));
                    break;
                }
            }
            if (type != LUA_TSTRING) luaL_error(L, "lunqlite read key type %s not suppert!", lua_typename(L, idx));
            return lua_tolstring(L, idx, len);
        }

        const char* read_value(lua_State* L, int idx, size_t* len) {
            int type = lua_type(L, idx);
            if (m_jcodec) {
                switch (type) {
                case LUA_TNIL:
                case LUA_TTABLE:
                case LUA_TNUMBER:
                case LUA_TSTRING:
                case LUA_TBOOLEAN:
                    return (const char*)m_jcodec->encode(L, idx, len);
                default:
                    luaL_error(L, "lunqlite read value type %s not suppert!", lua_typename(L, idx));
                    break;
                }
            }
            switch (type) {
            case LUA_TNUMBER:
            case LUA_TSTRING:
                return lua_tolstring(L, idx, len);
            default:
                luaL_error(L, "lunqlite read value type %d not suppert!", type);
                break;
            }
            return nullptr;
        }

        void push_value(lua_State* L, size_t len) {
            if (m_jcodec) {
                try {
                    m_jcodec->decode(L, (uint8_t*)m_buf, len);
                } catch (...) {
                    lua_pushlstring(L, (const char*)m_buf, len);
                }
                return;
            }
            if (lua_stringtonumber(L, m_buf) == 0) {
                lua_pushlstring(L, (const char*)m_buf, len);
            }
        }

    protected:
        unqlite* m_udb = nullptr;
        unqlite_kv_cursor* m_ucur = nullptr;
        codec_base* m_jcodec = nullptr;
        char m_buf[max_jsonbuf_size];
    };
}
