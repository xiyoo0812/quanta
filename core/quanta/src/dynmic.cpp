#define LUA_LIB

#include "quanta.h"

static quanta_app q_app;

extern "C" {

    int luaopen_lssl(lua_State* L);
    int luaopen_lbson(lua_State* L);
    int luaopen_ljson(lua_State* L);
    int luaopen_luapb(lua_State* L);
    int luaopen_lsmdb(lua_State* L);
    int luaopen_lualog(lua_State* L);
    int luaopen_luabus(lua_State* L);
    int luaopen_lcodec(lua_State* L);
    int luaopen_ltimer(lua_State* L);
    int luaopen_lminiz(lua_State* L);
    int luaopen_lworker(lua_State* L);
    int luaopen_lstdfs(lua_State* L);

    static void luaL_register_quantalibs(lua_State* L) {
        luaL_requiref(L, "lssl", luaopen_lssl, 1);
        luaL_requiref(L, "lbson", luaopen_lbson, 1);
        luaL_requiref(L, "ljson", luaopen_ljson, 1);
        luaL_requiref(L, "luapb", luaopen_luapb, 1);
        luaL_requiref(L, "lsmdb", luaopen_lsmdb, 1);
        luaL_requiref(L, "lualog", luaopen_lualog, 1);
        luaL_requiref(L, "luabus", luaopen_luabus, 1);
        luaL_requiref(L, "lcodec", luaopen_lcodec, 1);
        luaL_requiref(L, "ltimer", luaopen_ltimer, 1);
        luaL_requiref(L, "lworker", luaopen_lworker, 1);
        luaL_requiref(L, "lstdfs", luaopen_lstdfs, 1);
    }

    LUALIB_API bool init_quanta(lua_State* L, cpchar fconf) {
        #ifdef WIN32
            setlocale(LC_ALL, ".UTF8");
        #endif
        const char* args[2]{ "quanta", fconf };
        luaL_register_quantalibs(L);
        q_app.setup(2, args, L);
        q_app.set_library();
       return q_app.init();
    }

    LUALIB_API bool run_quanta() {
        return q_app.step();
    }
}
