#define LUA_LIB

#include "lprofile.h"

namespace lprofile {
    thread_local profile tprofile;

    int open_lprofile(lua_State* L) {
        luakit::kit_state kit_state(L, true);
        auto prof = kit_state.new_table();
        prof.set_function("enable", []() { tprofile.enable(); });
        prof.set_function("disable", []() { tprofile.disable(); });
        prof.set_function("hook", [](lua_State* pL) { 
            return tprofile.hook(pL);
        });
        prof.set_function("watch", [](lua_State* pL) {
            return tprofile.watch(pL);
        });
        prof.set_function("dump", [](lua_State* pL, uint32_t top) {
            return tprofile.dump(pL, top);
        });
        prof.set_function("flame", [](cpchar filename, bool include_suspend) {
            return tprofile.flame(filename, include_suspend);
        });
        prof.set_function("ignore", [](lua_State* pL, cpchar library) {
            return tprofile.ignore(pL, library);
        });
        prof.set_function("ignore_file", [](cpchar filename) {
            tprofile.ignore_file(filename);
        });
        prof.set_function("ignore_func", [](cpchar funcname) {
            tprofile.ignore_func(funcname);
        });
        kit_state.add_library_hooker(&tprofile);
        return kit_state.register_lib("profile", prof);
    }
}

extern "C" {
    LUALIB_API int luaopen_lprofile(lua_State* L) {
        return lprofile::open_lprofile(L);
    }
}