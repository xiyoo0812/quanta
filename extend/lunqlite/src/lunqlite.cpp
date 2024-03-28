#define LUA_LIB

#include "lunqlite.h"

namespace lunqlite {
    unqlite_driver* create_criver(lua_State* L) {
        return new unqlite_driver();
    }

    void destory() {
        unqlite_lib_shutdown();
    }

    luakit::lua_table open_lunqlite(lua_State* L) {
        luakit::kit_state kit_state(L);
        auto unqlite = kit_state.new_table();
        unqlite.set_function("destory", destory);
        unqlite.set_function("create", create_criver);
        kit_state.new_class<unqlite_driver>(
            "get", &unqlite_driver::get,
            "put", &unqlite_driver::put,
            "del", &unqlite_driver::del,
            "open", &unqlite_driver::open,
            "close", &unqlite_driver::close,
            "begin", &unqlite_driver::begin,
            "commit", &unqlite_driver::commit,
            "rollback", &unqlite_driver::rollback,
            "cursor_seek", &unqlite_driver::cursor_seek,
            "cursor_last", &unqlite_driver::cursor_last,
            "cursor_next", &unqlite_driver::cursor_next,
            "cursor_prev", &unqlite_driver::cursor_prev,
            "cursor_close", &unqlite_driver::cursor_close,
            "cursor_first", &unqlite_driver::cursor_first,
            "set_codec", &unqlite_driver::set_codec
            );
        unqlite.new_enum("UNQLITE_CODE",
            "UNQLITE_OK", UNQLITE_OK,
            "UNQLITE_NOMEM", UNQLITE_NOMEM,
            "UNQLITE_ABORT", UNQLITE_ABORT,
            "UNQLITE_IOERR", UNQLITE_IOERR,
            "UNQLITE_CORRUPT", UNQLITE_CORRUPT,
            "UNQLITE_LOCKED", UNQLITE_LOCKED,
            "UNQLITE_BUSY", UNQLITE_BUSY,
            "UNQLITE_DONE", UNQLITE_DONE,
            "UNQLITE_PERM", UNQLITE_PERM,
            "UNQLITE_NOTIMPLEMENTED", UNQLITE_NOTIMPLEMENTED,
            "UNQLITE_NOTFOUND", UNQLITE_NOTFOUND,
            "UNQLITE_NOOP", UNQLITE_NOOP,
            "UNQLITE_INVALID", UNQLITE_INVALID,
            "UNQLITE_EOF", UNQLITE_EOF,
            "UNQLITE_UNKNOWN", UNQLITE_UNKNOWN,
            "UNQLITE_LIMIT", UNQLITE_LIMIT,
            "UNQLITE_EXISTS", UNQLITE_EXISTS,
            "UNQLITE_EMPTY", UNQLITE_EMPTY,
            "UNQLITE_COMPILE_ERR", UNQLITE_COMPILE_ERR,
            "UNQLITE_VM_ERR", UNQLITE_VM_ERR,
            "UNQLITE_FULL", UNQLITE_FULL,
            "UNQLITE_CANTOPEN", UNQLITE_CANTOPEN,
            "UNQLITE_READ_ONLY", UNQLITE_READ_ONLY,
            "UNQLITE_LOCKERR", UNQLITE_LOCKERR
        );
        return unqlite;
    }
}

extern "C" {
    LUALIB_API int luaopen_lunqlite(lua_State* L) {
        auto unqlite = lunqlite::open_lunqlite(L);
        return unqlite.push_stack();
    }
}