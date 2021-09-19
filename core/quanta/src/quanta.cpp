#include <stdlib.h>
#include <stdio.h>
#include <locale>
#include <signal.h>
#include "quanta.h"

#if WIN32
#include <conio.h>
#include <windows.h>
#define setenv(k,v,o) _putenv_s(k, v);
#endif

#define QUANTA_APP_META  "_QUANTA_APP_META"

quanta_app* g_app = nullptr;
static void on_signal(int signo) {
    if (g_app) {
        g_app->set_signal(signo);
    }
}

static const char* get_platform() {
#if defined(__linux)
    return "linux";
#elif defined(__APPLE__)
    return "apple";
#else
    return "windows";
#endif
}

static int get_pid(lua_State* L) {
#ifdef _MSC_VER
    lua_pushinteger(L, ::GetCurrentProcessId());
#else
    lua_pushinteger(L, ::getpid());
#endif
    return 1;
}
static int daemon(lua_State* L) {
#if defined(__linux) || defined(__APPLE__)
    pid_t pid = fork();
    if (pid != 0)
        exit(0);

    setsid();
    umask(0);
    int null = open("/dev/null", O_RDWR);
    if (null != -1) {
        dup2(null, STDIN_FILENO);
        dup2(null, STDOUT_FILENO);
        dup2(null, STDERR_FILENO);
        close(null);
    }
#endif
    return 0;
}

static int register_signal(lua_State* L) {
    int signalv = lua_tointeger(L, 1);
    signal(signalv, on_signal);
    return 0;
}

static int default_signal(lua_State* L) {
    int signalv = lua_tointeger(L, 1);
    signal(signalv, SIG_DFL);
    return 0;
}

static int ignore_signal(lua_State* L) {
    int signalv = lua_tointeger(L, 1);
    signal(signalv, SIG_IGN);
    return 0;
}

static int get_signal(lua_State* L) {
    lua_pushinteger(L, g_app ? g_app->get_signal() : 0);
    return 1;
}

static int set_signal(lua_State* L) {
    if (g_app) {
        int signalv = lua_tointeger(L, 1);
        g_app->set_signal(signalv);
    }
    return 1;
}

static bool load_quanta_func(lua_State* L, const char* func) {
    lua_getglobal(L, "quanta");
    lua_getfield(L, -1, func);
    return lua_isfunction(L, -1);
}

static void check_input(lua_State* L) {
#ifdef WIN32
    if (kbhit()) {
        char cur = getch();
        if (cur == '\xE0' || cur == '\x0') {
            if (kbhit()) {
                getch();
                return;
            }
        }
        int top = lua_gettop(L);
        if (load_quanta_func(L, "console")) {
            lua_pushinteger(L, cur);
            lua_pcall(L, 1, 0, -2);
        }
        lua_settop(L, top);
    }
#endif
}

static int set_env(lua_State* L) {
    bool replace = false;
    const char* env_name = lua_tostring(L, 1);
    const char* env_value = lua_tostring(L, 2);
    if (lua_gettop(L) == 3) {
        replace = lua_toboolean(L, 3);
    }
    if (replace || !getenv(env_name)) {
        setenv(env_name, env_value, 1);
    }
    return 0;
}

static const luaL_Reg lquanta[] = {
    { "daemon" , daemon },
    { "set_env", set_env },
    { "get_pid", get_pid },
    { "set_signal", set_signal },
    { "get_signal", get_signal },
    { "ignore_signal", ignore_signal },
    { "default_signal", default_signal },
    { "register_signal", register_signal },
    { NULL, NULL }
};

uint64_t quanta_app::get_signal() {
    return m_signal;
}

void quanta_app::set_signal(int n) {
    uint64_t mask = 1;
    mask <<= n;
    m_signal |= mask;
}

void quanta_app::load_config(int argc, const char* argv[]) {
    const char* conf_file = argv[1];
    lua_State* L = luaL_newstate();
    luaL_openlibs(L);

    lua_pushstring(L, get_platform());
    lua_setglobal(L, "platform");
    lua_pushcfunction(L, set_env);
    lua_setglobal(L, "set_env");

    //加载配置表
    luaL_dofile(L, conf_file);
    //设置默认INDEX
    setenv("QUANTA_INDEX", "1", 1);
    //将启动参数转换成环境变量
    for (int i = 2; i < argc; ++i) {
        const char* begin = argv[i];
        const char* pos = strchr(argv[i], '=');
        if (*(begin++) == '-' && *(begin++) == '-' && pos != NULL && begin != pos) {
            char env_n[256] = { 0 };
            strcpy(env_n, "QUANTA_");
            strncpy(env_n + strlen(env_n), begin, pos - begin);
            lua_pushlstring(L, ++pos, (argv[i] + strlen(argv[i]) - pos));
            char* env_name = strupr(env_n);
            const char* env_value = lua_tostring(L, -1);
            setenv(env_name, env_value, 1);
            lua_pop(L, 1);
        }
    }
    lua_close(L);
}

void quanta_app::run(int argc, const char* argv[]) {
    if (argc > 0) {
        load_config(argc, argv);
    }
    lua_State* L = luaL_newstate();
    luaL_openlibs(L);
    lua_newtable(L);
    luaL_newmetatable(L, QUANTA_APP_META);
    luaL_setfuncs(L, lquanta, 0);
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    lua_setmetatable(L, -2);
    lua_newtable(L);
    for (int i = 1; i < argc; i++) {
        lua_pushinteger(L, i - 1);
        lua_pushstring(L, argv[i]);
        lua_settable(L, -3);
    }
    lua_setfield(L, -2, "args");
    lua_pushstring(L, get_platform());
    lua_setfield(L, -2, "platform");
    lua_setglobal(L, "quanta");

    lua_getglobal(L, "require");
    lua_pushvalue(L, -1);
    lua_pushstring(L, getenv("QUANTA_SANDBOX"));
    if (lua_pcall(L, 1, 0, -2) != LUA_OK) {
        exit(1);
    }
    lua_pushstring(L, getenv("QUANTA_ENTRY"));
    if (lua_pcall(L, 1, 0, -2) != LUA_OK) {
        exit(1);
    }
    int top = lua_gettop(L);
    while (load_quanta_func(L, "run")) {
        check_input(L);
        lua_pcall(L, 0, 0, -1);
        lua_settop(L, top);
    }
    lua_close(L);
}
