#define LUA_LIB

#include "lsqlite.h"

namespace lsqlite {
    sqlite_driver* create_criver(lua_State* L) {
        return new sqlite_driver();
    }

    luakit::lua_table open_lsqlite(lua_State* L) {
        luakit::kit_state kit_state(L);
        auto sqlite = kit_state.new_table();
        sqlite.set_function("create", create_criver);
        kit_state.new_class<sqlite_stmt>(
            "sql", &sqlite_stmt::sql,
            "run", &sqlite_stmt::run,
            "bind", &sqlite_stmt::bind,
            "exec", &sqlite_stmt::exec,
            "close", &sqlite_stmt::close,
            "reset", &sqlite_stmt::reset,
            "parameter_count", &sqlite_stmt::parameter_count
        );
        kit_state.new_class<sqlite_driver>(
            "open", &sqlite_driver::open,
            "exec", &sqlite_driver::exec,
            "find", &sqlite_driver::find,
            "close", &sqlite_driver::close,
            "changes", &sqlite_driver::changes,
            "prepare", &sqlite_driver::prepare,
            "interrupt", &sqlite_driver::interrupt,
            "last_insert_rowid", &sqlite_driver::last_insert_rowid,
            "set_codec", &sqlite_driver::set_codec
        );
        sqlite.new_enum("SQLITE_CODE",
            "SQLITE_OK", SQLITE_OK,
            "SQLITE_ROW", SQLITE_ROW,
            "SQLITE_DONE", SQLITE_DONE,
            "SQLITE_ERROR", SQLITE_ERROR,
            "SQLITE_INTERNAL", SQLITE_INTERNAL,
            "SQLITE_PERM", SQLITE_PERM,
            "SQLITE_ABORT", SQLITE_ABORT,
            "SQLITE_BUSY", SQLITE_BUSY,
            "SQLITE_LOCKED", SQLITE_LOCKED,
            "SQLITE_NOMEM", SQLITE_NOMEM,
            "SQLITE_READONLY", SQLITE_READONLY,
            "SQLITE_INTERRUPT", SQLITE_INTERRUPT,
            "SQLITE_IOERR", SQLITE_IOERR,
            "SQLITE_CORRUPT", SQLITE_CORRUPT,
            "SQLITE_NOTFOUND", SQLITE_NOTFOUND,
            "SQLITE_FULL", SQLITE_FULL,
            "SQLITE_CANTOPEN", SQLITE_CANTOPEN,
            "SQLITE_PROTOCOL", SQLITE_PROTOCOL,
            "SQLITE_EMPTY", SQLITE_EMPTY,
            "SQLITE_SCHEMA", SQLITE_SCHEMA,
            "SQLITE_TOOBIG", SQLITE_TOOBIG,
            "SQLITE_CONSTRAINT", SQLITE_CONSTRAINT,
            "SQLITE_MISMATCH", SQLITE_MISMATCH,
            "SQLITE_MISUSE", SQLITE_MISUSE,
            "SQLITE_NOLFS", SQLITE_NOLFS,
            "SQLITE_AUTH", SQLITE_AUTH,
            "SQLITE_FORMAT", SQLITE_FORMAT,
            "SQLITE_RANGE", SQLITE_RANGE,
            "SQLITE_NOTADB", SQLITE_NOTADB
        );
        return sqlite;
    }
}

extern "C" {
    LUALIB_API int luaopen_lsqlite(lua_State* L) {
        auto sqlite = lsqlite::open_lsqlite(L);
        return sqlite.push_stack();
    }
}