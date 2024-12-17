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
        smdb.new_enum("smdb_code",
            "SMDB_SUCCESS", smdb_code::SMDB_SUCCESS,
            "SMDB_DB_NOT_INIT", smdb_code::SMDB_DB_NOT_INIT,
            "SMDB_DB_ITER_ING", smdb_code::SMDB_DB_ITER_ING,
            "SMDB_SIZE_KEY_FAIL", smdb_code::SMDB_SIZE_KEY_FAIL,
            "SMDB_SIZE_VAL_FAIL", smdb_code::SMDB_SIZE_VAL_FAIL,
            "SMDB_FILE_OPEN_FAIL", smdb_code::SMDB_FILE_OPEN_FAIL,
            "SMDB_FILE_FDNO_FAIL", smdb_code::SMDB_FILE_FDNO_FAIL,
            "SMDB_FILE_MMAP_FAIL", smdb_code::SMDB_FILE_MMAP_FAIL,
            "SMDB_FILE_HANDLE_FAIL", smdb_code::SMDB_FILE_HANDLE_FAIL,
            "SMDB_FILE_MAPPING_FAIL", smdb_code::SMDB_FILE_MAPPING_FAIL,
            "SMDB_FILE_EXPAND_FAIL", smdb_code::SMDB_FILE_EXPAND_FAIL
        );
        kit_state.new_class<smdb_driver>(
            "get", &smdb_driver::get,
            "put", &smdb_driver::put,
            "del", &smdb_driver::del,
            "open", &smdb_driver::open,
            "next", &smdb_driver::next,
            "size", &smdb_driver::size,
            "count", &smdb_driver::count,
            "first", &smdb_driver::first,
            "flush", &smdb_driver::flush,
            "close", &smdb_driver::close,
            "clear", &smdb_driver::clear,
            "capacity", &smdb_driver::capacity,
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