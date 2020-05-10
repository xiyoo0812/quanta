/*
** repository: https://github.com/trumanzhao/luna
** trumanzhao, 2017-05-13, trumanzhao@foxmail.com
*/

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <string>
#include <locale>
#include <stdint.h>
#include <signal.h>
#include "quanta.h"
#include "tools.h"
#if WIN32
#include <conio.h>
#define setenv(k,v,o) _putenv_s(k, v);
#endif

quanta_app* g_app = nullptr;

static void on_signal(int signo)
{
    if (g_app)
    {
        g_app->set_signal(signo);
    }
}

EXPORT_CLASS_BEGIN(quanta_app)
EXPORT_LUA_FUNCTION(get_version)
EXPORT_LUA_FUNCTION(get_file_time)
EXPORT_LUA_FUNCTION(get_full_path)
EXPORT_LUA_FUNCTION(get_time_ms)
EXPORT_LUA_FUNCTION(get_time_ns)
EXPORT_LUA_FUNCTION(get_pid)
EXPORT_LUA_FUNCTION(sleep_ms)
EXPORT_LUA_FUNCTION(daemon)
EXPORT_LUA_FUNCTION(register_signal)
EXPORT_LUA_FUNCTION(default_signal)
EXPORT_LUA_FUNCTION(ignore_signal)
EXPORT_LUA_INT64(m_signal)
EXPORT_LUA_INT(m_reload_time)
EXPORT_CLASS_END()

int quanta_app::get_version(lua_State* L)
{
    lua_pushinteger(L, MAJOR_VERSION_NUMBER);
    lua_pushinteger(L, MINOR_VERSION_NUMBER);
    lua_pushinteger(L, REVISION_NUMBER);
    return 3;
}

time_t quanta_app::get_file_time(const char* filename)
{
    return ::get_file_time(filename);
}

int quanta_app::get_full_path(lua_State* L)
{
    const char* path = lua_tostring(L, 1);
    std::string fullpath;
    if (path != nullptr && ::get_full_path(fullpath, path))
    {
        lua_pushstring(L, fullpath.c_str());
    }
    return 1;
}

int64_t quanta_app::get_time_ms()
{
    return ::get_time_ms();
}

int64_t quanta_app::get_time_ns()
{
    return ::get_time_ns();
}

int32_t quanta_app::get_pid()
{
#ifdef _MSC_VER
    return ::GetCurrentProcessId();
#else
    return ::getpid();
#endif
}

void quanta_app::sleep_ms(int ms)
{
    ::sleep_ms(ms);
}

#ifdef _MSC_VER
void quanta_app::daemon() { }
#endif

#if defined(__linux) || defined(__APPLE__)
void quanta_app::daemon()
{
    pid_t pid = fork();
    if (pid != 0)
        exit(0);

    setsid();
    umask(0);
    
    int null = open("/dev/null", O_RDWR); 
    if (null != -1)
    {
        dup2(null, STDIN_FILENO);
        dup2(null, STDOUT_FILENO);
        dup2(null, STDERR_FILENO);
        close(null);
    }
}
#endif

void quanta_app::register_signal(int n)
{
    signal(n, on_signal);
}

void quanta_app::default_signal(int n)
{
    signal(n, SIG_DFL);
}

void quanta_app::ignore_signal(int n)
{
    signal(n, SIG_IGN);
}

void quanta_app::set_signal(int n)
{
    uint64_t mask = 1;
    mask <<= n;
    m_signal |= mask;
}

void quanta_app::check_input(lua_State* L)
{
#ifdef WIN32
    if (kbhit())
    {
        char cur = getch();
        if (cur == '\xE0' || cur == '\x0')
        {
            if (kbhit())
            {
                getch();
                return;
            }
        }
        lua_call_object_function(L, nullptr, this, "input", std::tie(), cur);
    }
#endif
}

int set_env(lua_State *L)
{
    bool replae = false;
    const char* env_name = lua_tostring(L, 1);
    const char* env_value = lua_tostring(L, 2);
    if (lua_gettop(L) == 3)
    {
        replae = lua_toboolean(L, 3);
    }
    if (replae || !getenv(env_name))
    {
        setenv(env_name, env_value, 1);
    }
    return 0;
}

void quanta_app::load_config(int argc, const char* argv[])
{
    const char* conf_file = argv[1];
    lua_State* L = luaL_newstate();
    luaL_openlibs(L);

    lua_pushstring(L, get_platform());
    lua_setglobal(L, "platform");
    lua_register_function(L, "set_env", set_env);

    //加载配置表
    luaL_dofile(L, conf_file);
    //设置默认INDEX
    setenv("QUANTA_INDEX", "1", 1);
    //将启动参数转换成环境变量
    for (int i = 2; i < argc; ++i)
    {
        const char* begin = argv[i];
        const char* pos = strchr(argv[i], '=');
        if (*(begin++) == '-' && *(begin++) == '-' && pos != NULL && begin != pos)
        {
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

void quanta_app::die(const std::string& err)
{
    FILE* file = fopen("quanta.err", "w");
    if (file != nullptr)
    {
        fwrite(err.c_str(), err.length(), 1, file);
        fclose(file);
    }
    fprintf(stderr, "%s", err.c_str());
    exit(1);
}

void quanta_app::run(int argc, const char* argv[])
{
    load_config(argc, argv);
    lua_State* L = luaL_newstate();
    luaL_openlibs(L);
    lua_push_object(L, this);
    lua_push_object(L, this);
    lua_setglobal(L, "quanta");
    lua_newtable(L);
    for (int i = 1; i < argc; i++)
    {
        lua_pushinteger(L, i - 1);
        lua_pushstring(L, argv[i]);
        lua_settable(L, -3);
    }
	lua_setfield(L, -2, "args");
	lua_pushstring(L, get_platform());
	lua_setfield(L, -2, "platform");

    std::string err;
    if (!lua_call_global_function(L, &err, "require", std::tie(), getenv("QUANTA_SANDBOX"))) 
    {
        die(err);
    }
    if (!lua_call_global_function(L, &err, "require", std::tie(), getenv("QUANTA_ENTRY")))
    {
        die(err);
    }

    int top = lua_gettop(L);
    int64_t last_check = ::get_time_ms();
    while (lua_get_object_function(L, this, "run"))
    {
        check_input(L);
        lua_call_function(L, &err, 0, 0);

        int64_t now = ::get_time_ms();
        if (now > last_check + m_reload_time)
        {
            lua_call_object_function(L, nullptr, this, "reload");
            last_check = now;
        }
        lua_settop(L, top);
    }
    lua_close(L);
}
