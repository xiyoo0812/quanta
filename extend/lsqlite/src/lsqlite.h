#pragma once

#include "sqlite3.h"
#include "lua_kit.h"

using namespace std;
using namespace luakit;

namespace lsqlite {
    class sqlite_stmt {
    public:
        sqlite_stmt(sqlite3* db, sqlite3_stmt* stmt, codec_base* codec) : m_sdb(db), m_stmt(stmt), m_jcodec(codec){}
        ~sqlite_stmt() { close(); }

        void close() {
            if (m_stmt) sqlite3_finalize(m_stmt);
            m_stmt = nullptr;
            m_sdb = nullptr;
        }
        void reset() {
            sqlite3_reset(m_stmt);
        }
        const char* sql() {
            return sqlite3_sql(m_stmt);
        }
        int parameter_count() {
            return sqlite3_bind_parameter_count(m_stmt);
        }
        int bind(lua_State* L) {
            int type = lua_type(L, 1);
            if (type == LUA_TTABLE) {
                bind_table(L, 1);
            } else {
                bind_value(L, find_param_index(L, 1), 2);
            }
            return 0;
        }
        int run(lua_State* L) {
            if (lua_type(L, 1) == LUA_TTABLE) {
                bind_table(L, 1);
                return exec(L);
            }
            int top = lua_gettop(L);
            for (int i = 1; i <= top; ++i) {
                bind_value(L, i, i);
            }
            return exec(L);
        }
        int exec(lua_State* L) {
            int rc = sqlite3_step(m_stmt);
            if (rc != SQLITE_DONE && rc != SQLITE_ROW) {
                sqlite3_reset(m_stmt);
                return handler_err(L, rc);
            }
            int index = 0;
            lua_createtable(L, 0, 4);
            while(rc == SQLITE_ROW) {
                lua_createtable(L, 0, 4);
                int ncol = sqlite3_data_count(m_stmt);
                for (int col = 0; col < ncol; ++col) {
                    lua_pushstring(L, sqlite3_column_name(m_stmt, col));
                    push_column(L, col);
                    lua_rawset(L, -3);
                }
                lua_seti(L, -2, ++index);
                rc = sqlite3_step(m_stmt);
            }
            sqlite3_reset(m_stmt);
            lua_pushinteger(L, rc);
            lua_insert(L, -2);
            return 2;
        }

    protected:
        int handler_err(lua_State* L, int rc) {
            lua_pushinteger(L, rc);
            if (rc == SQLITE_ERROR) {
                lua_pushstring(L, sqlite3_errmsg(m_sdb));
                return 2;
            }
            return 1;
        }

        void push_column(lua_State* L, int col) {
            switch (sqlite3_column_type(m_stmt, col)) {
            case SQLITE_FLOAT: lua_pushnumber(L, sqlite3_column_double(m_stmt, col)); break;
            case SQLITE_INTEGER: lua_pushinteger(L, sqlite3_column_int64(m_stmt, col)); break;
            case SQLITE_TEXT: lua_pushlstring(L, (const char*)sqlite3_column_text(m_stmt, col), sqlite3_column_bytes(m_stmt, col)); break;
            case SQLITE_BLOB: {
                try {
                    m_jcodec->decode(L, (uint8_t*)sqlite3_column_blob(m_stmt, col), sqlite3_column_bytes(m_stmt, col));
                } catch (...) {
                    lua_pushlstring(L, (const char*)sqlite3_column_blob(m_stmt, col), sqlite3_column_bytes(m_stmt, col));
                }
            }
            break;
            default: lua_pushnil(L); break;
            }
        }
        void bind_table(lua_State* L, int index) {
            lua_pushnil(L);
            while (lua_next(L, index)) {
                bind_value(L, find_param_index(L, -2), -1);
                lua_pop(L, 1);
            }
        }
        void bind_value(lua_State* L, int param_index, int vidx) {
            switch (lua_type(L, vidx)) {
            case LUA_TNIL: sqlite3_bind_null(m_stmt, param_index); break;
            case LUA_TBOOLEAN: sqlite3_bind_int(m_stmt, param_index, lua_tointeger(L, vidx)); break;
            case LUA_TNUMBER: {
                if (lua_isinteger(L, vidx)) sqlite3_bind_int(m_stmt, param_index, lua_tointeger(L, vidx));
                else sqlite3_bind_double(m_stmt, param_index, lua_tonumber(L, vidx));
            }
            break;
            case LUA_TSTRING: {
                size_t len;
                const char* str = luaL_checklstring(L, vidx, &len);
                sqlite3_bind_text(m_stmt, param_index, str, len, SQLITE_TRANSIENT);
            }
            break;
            case LUA_TTABLE: {
                size_t len;
                if (!m_jcodec) luaL_error(L, "sqlite bind_value value type %s not suppert!", lua_typename(L, vidx));
                const char* str = (const char*)m_jcodec->encode(L, vidx, &len);
                sqlite3_bind_blob(m_stmt, param_index, str, len, SQLITE_TRANSIENT);
            }
            break;
            default: luaL_error(L, "sqlite bind_value value type %s not suppert!", lua_typename(L, vidx)); break;
            }
        }
        int find_param_index(lua_State* L, int kidx) {
            int pindex = 0;
            switch (lua_type(L, kidx)) {
            case LUA_TNUMBER: pindex = lua_tointeger(L, kidx); break;
            case LUA_TSTRING: pindex = sqlite3_bind_parameter_index(m_stmt, lua_tostring(L, kidx)); break;
            default: luaL_error(L, "sqlite bind index type %s not suppert!", lua_typename(L, kidx)); break;
            }
            if (pindex == 0) luaL_error(L, "sqlite bind index value is zero!");
            return pindex;
        }

    private:
        sqlite3* m_sdb = nullptr;
        sqlite3_stmt* m_stmt = nullptr;
        codec_base* m_jcodec = nullptr;
    };

    class sqlite_driver {
    public:
        sqlite_driver() {}
        ~sqlite_driver() { close(); }

        void close() {
            if (m_sdb) sqlite3_close_v2(m_sdb);
            m_sdb = nullptr;
        }

        void set_codec(codec_base* codec) {
            m_jcodec = codec;
        }

        codec_base* get_codec() {
            return m_jcodec;
        }
        
        int open(lua_State* L) {
            const char* path = luaL_optstring(L, 1, ":memory:");
            int rc = sqlite3_open(path, &m_sdb);
            return handler_err(L, rc);
        }

        void interrupt() {
            sqlite3_interrupt(m_sdb);
        }

        int changes(lua_State* L) {
            int rc = sqlite3_changes(m_sdb);
            return handler_err(L, rc);
        }

        int last_insert_rowid() {
            return sqlite3_last_insert_rowid(m_sdb);
        }

        int exec(lua_State* L) {
            const char* sql = luaL_checklstring(L, 1, nullptr);
            int rc = sqlite3_exec(m_sdb, sql, nullptr, nullptr, nullptr);
            lua_pushinteger(L, rc);
            if (rc != SQLITE_OK) {
                return handler_err(L, rc);
            }
            return 1;
        }

        int find(lua_State* L) {
            char** result;
            int nrow, ncol;
            const char* sql = luaL_checklstring(L, 1, nullptr);
            int rc = sqlite3_get_table(m_sdb, sql, &result, &nrow, &ncol, nullptr);
            if (rc != SQLITE_OK) {
                return handler_err(L, rc);
            }
            char** olres = result;
            std::vector<char*> titles;
            for (int c = 0; c < ncol; ++c, result++) {
                titles.push_back(*result);
            }
            lua_pushinteger(L, rc);
            lua_createtable(L, 0, (nrow > 0) ? nrow - 1 : 0);
            for (int r = 0; r < nrow; ++r) {
                lua_createtable(L, 0, ncol);
                for (int c = 0; c < ncol; ++c, result++) {
                    char* value = *result;
                    if (lua_stringtonumber(L, value) == 0) {
                        lua_pushstring(L, value);
                    }
                    lua_setfield(L, -2, titles[c]);
                }
                lua_seti(L, -2, r + 1);
            }
            sqlite3_free_table(olres);
            return 2;
        }

        int prepare(lua_State* L) {
            size_t size;
            sqlite3_stmt* stmt;
            const char* sql = luaL_checklstring(L, 1, &size);
            int rc = sqlite3_prepare_v2(m_sdb, sql, size, &stmt, nullptr);
            if (rc != SQLITE_OK) {
                return handler_err(L, rc);
            }
            lua_pushinteger(L, rc);
            lua_push_object(L, new sqlite_stmt(m_sdb, stmt, m_jcodec));
            return 2;
        }

    protected:
        int handler_err(lua_State* L, int rc) {
            lua_pushinteger(L, rc);
            if (rc != SQLITE_OK) {
                lua_pushstring(L, sqlite3_errmsg(m_sdb));
                return 2;
            }
            return 1;
        }

    protected:
        sqlite3* m_sdb = nullptr;
        codec_base* m_jcodec = nullptr;
    };
}
