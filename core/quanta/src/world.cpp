#include <stdio.h>
#include "world.h"
#include "quanta.h"

#ifdef __cplusplus
extern "C" {
#endif

int luaopen_lbson(lua_State* L);
int luaopen_ljson(lua_State* L);
int luaopen_luapb(lua_State* L);
int luaopen_lualog(lua_State* L);
int luaopen_luabus(lua_State* L);
int luaopen_lcodec(lua_State* L);
int luaopen_lcrypt(lua_State* L);
int luaopen_ltimer(lua_State* L);
int luaopen_lsqlite(lua_State* L);

#ifdef __cplusplus
}
#endif

#ifdef WIN32
#define tzset _tzset
#endif

#define WORLD_ARGS_NUM 2

static void luaL_open_worldlibs(lua_State* L) {
    luaopen_lbson(L);
    luaopen_ljson(L);
    luaopen_luapb(L);
    luaopen_lualog(L);
    luaopen_luabus(L);
    luaopen_lcodec(L);
    luaopen_lcrypt(L);
    luaopen_ltimer(L);
    luaopen_lsqlite(L);
}

WORLD_API int run_world(const char* fconf) {
    setlocale(LC_ALL, "");
#if !(defined(__ORBIS__) || defined(__PROSPERO__))
    tzset();
    system("echo quanta engine init.");
#endif
    quanta_app q_app;
    //初始化lua扩展
    luaL_open_worldlibs(q_app.L());
    const char* args[WORLD_ARGS_NUM]{ "world", fconf };
    //启动主循环
    q_app.setup(WORLD_ARGS_NUM, args);
    return 0;
}
