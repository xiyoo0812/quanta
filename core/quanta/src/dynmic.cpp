#define LUA_LIB
#include <signal.h>

#include "quanta.h"

extern "C" {
    int luaopen_ljson(lua_State* L);
    int luaopen_luapb(lua_State* L);
    int luaopen_lsmdb(lua_State* L);
    int luaopen_luassl(lua_State* L);
    int luaopen_lualog(lua_State* L);
    int luaopen_luabus(lua_State* L);
    int luaopen_lcodec(lua_State* L);
    int luaopen_ltimer(lua_State* L);
    int luaopen_luazip(lua_State* L);
    int luaopen_lworker(lua_State* L);
    int luaopen_lstdfs(lua_State* L);

    static void luaL_register_quantalibs(lua_State* L) {
        luaL_requiref(L, "ljson", luaopen_ljson, 1);
        luaL_requiref(L, "luapb", luaopen_luapb, 1);
        luaL_requiref(L, "lsmdb", luaopen_lsmdb, 1);
        luaL_requiref(L, "luassl", luaopen_luassl, 1);
        luaL_requiref(L, "lualog", luaopen_lualog, 1);
        luaL_requiref(L, "luabus", luaopen_luabus, 1);
        luaL_requiref(L, "lcodec", luaopen_lcodec, 1);
        luaL_requiref(L, "ltimer", luaopen_ltimer, 1);
        luaL_requiref(L, "lstdfs", luaopen_lstdfs, 1);
        luaL_requiref(L, "luazip", luaopen_luazip, 1);
        luaL_requiref(L, "lworker", luaopen_lworker, 1);
    }

    static sstring LAST_ERR = "";

    LUALIB_API cpchar last_error() {
        return LAST_ERR.c_str();
    }

    LUALIB_API quanta_app* init_quanta(lua_State* L, int argc, cpchar argv[]) {
        LAST_ERR.clear();
        setlocale(LC_ALL, ".UTF8");
        luaL_register_quantalibs(L);
        quanta_app* app = new quanta_app();
        if (!app->setup(argc, argv, L)) {
            LAST_ERR = app->last_error();
            delete app;
            app = nullptr;
        }
        return app;
    }

    LUALIB_API bool run_quanta(quanta_app* app) {
        return app->step();
    }

    LUALIB_API void stop_quanta(quanta_app* app) {
        app->set_signal(SIGTERM, true);
        while (true) {
            std::this_thread::sleep_for(std::chrono::milliseconds(5));
            if (!app->step()) break;
        }
        delete app;
    }
}
