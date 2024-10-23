#define LUA_LIB

#include "scheduler.h"

using vstring   = std::string_view;

namespace lworker {

    static scheduler schedulor;
    luakit::lua_table open_lworker(lua_State* L) {
        luakit::kit_state kit_state(L);
        auto llworker = kit_state.new_table("worker");
        llworker.set_function("shutdown", []() { schedulor.shutdown(); });
        llworker.set_function("update", [&](uint64_t clock_ms) { schedulor.update(clock_ms); });
        llworker.set_function("broadcast", [&](lua_State* L) { return schedulor.broadcast(L); });
        llworker.set_function("setup", [](lua_State* L, vstring ns) {
            schedulor.setup(L, ns);
            return 0;
        });
        llworker.set_function("startup", [](lua_State* L, vstring name, vstring conf) {
            environ_map args;
            lua_to_native(L, 3, args);
            return schedulor.startup(name, args, conf, lua_to_native<luakit::kit_state*>(L, 4));
        });
        llworker.set_function("stop", [](vstring name) {
            schedulor.stop(name);
        });
        llworker.set_function("call", [](lua_State* L, vstring name) {
            size_t data_len;
            uint8_t* data = schedulor.encode(L, data_len);
            return schedulor.call(L, name, data, data_len);
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
