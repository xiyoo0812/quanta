#define LUA_LIB

#include "lsmdb.h"

namespace lsmdb {
    smdb_driver* create_criver(lua_State* L) {
        return new smdb_driver();
    }

    luakit::lua_table open_lsmdb(lua_State* L) {
        luakit::kit_state kit_state(L);
        auto smdb = kit_state.new_table("smdb");
        smdb.set_function("create", create_criver);
        kit_state.new_class<smdb_driver>(
            "get", &smdb_driver::get,
            "put", &smdb_driver::put,
            "del", &smdb_driver::del,
            "open", &smdb_driver::open,
            "next", &smdb_driver::next,
            "first", &smdb_driver::first,
            "close", &smdb_driver::close,
            "arrange", &smdb_driver::arrange,
            "set_codec", &smdb_driver::set_codec
        );
        return smdb;
    }
}

extern "C" {
    LUALIB_API int luaopen_lsmdb(lua_State* L) {
        auto smdb = lsmdb::open_lsmdb(L);
        return smdb.push_stack();
    }
}