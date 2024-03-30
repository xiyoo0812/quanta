#include <stdio.h>
#include "mainlib.h"
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
int luaopen_lstdfs(lua_State* L);
int luaopen_ltimer(lua_State* L);
int luaopen_lsqlite(lua_State* L);
int luaopen_lworker(lua_State* L);

#ifdef __cplusplus
}
#endif

#ifdef WIN32
#define tzset _tzset
#endif

#define QUANTA_ARGS_NUM 2

static void luaL_open_worldlibs(lua_State* L) {
    luaopen_lbson(L);
    luaopen_ljson(L);
    luaopen_luapb(L);
    luaopen_lualog(L);
    luaopen_luabus(L);
    luaopen_lcodec(L);
    luaopen_lcrypt(L);
    luaopen_lstdfs(L);
    luaopen_ltimer(L);
    luaopen_lsqlite(L);
    luaopen_lworker(L);
}

quanta_app* q_app = nullptr;

QUANTA_API int quanta_init(const char* zfile, const char* fconf) {
    setlocale(LC_ALL, "");
#if !(defined(__ORBIS__) || defined(__PROSPERO__))
    tzset();
    system("echo quanta engine init.");
#endif
    if (!q_app) {
        q_app = new quanta_app();
        //初始化lua扩展
        luaL_open_worldlibs(q_app->L());
        //设置静态库模式
        q_app->set_env("QUANTA_STATIC", "1", 0);
        //加载zip文件
        q_app->initzip(zfile);
        const char* args[QUANTA_ARGS_NUM]{ "world", fconf};
        //启动主循环
        q_app->setup(QUANTA_ARGS_NUM, args);
    }
    return 0;
}

QUANTA_API int quanta_running() {
    if (q_app) {
        bool running = q_app->running();
        if (!running) {
            delete q_app;
            q_app = nullptr;
        }
        return running;
    }
    return false;
}

QUANTA_API int run_quanta() {
    if (q_app) {;
        if (!q_app->step()) {
            delete q_app;
            q_app = nullptr;
            return 0
        }
        return 1;
    }
    return 0;
}
