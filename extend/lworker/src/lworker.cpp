#define LUA_LIB

#include "scheduler.h"

namespace lworker {

    static scheduler schedulor;
    luakit::lua_table open_lworker(lua_State* L) {
        luakit::kit_state kit_state(L);
        auto llworker = kit_state.new_table();
        llworker.set_function("update", []() { schedulor.update(); });
        llworker.set_function("shutdown", []() { schedulor.shutdown(); });
        llworker.set_function("setup", [](lua_State* L, std::string service, std::string sandbox) {
            schedulor.setup(L, service, sandbox);
            return 0;
        });
        llworker.set_function("startup", [](std::string name, std::string entry) {
            return schedulor.startup(name, entry);
        });
        llworker.set_function("call", [](std::string name, slice* buf) {
            return schedulor.call(name, buf);
        });
        return llworker;
    }
}

extern "C" {
    LUALIB_API int luaopen_lworker(lua_State* L) {
        auto llworker = lworker::open_lworker(L);
        return llworker.push_stack();
    }
}
