#include <stdlib.h>
#include <locale>
#include <signal.h>
#include "quanta.h"

#include "sol/sol.hpp"

#if WIN32
#include <conio.h>
#include <windows.h>
#define setenv(k,v,o) _putenv_s(k, v);
#else
#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>
#endif

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

static int get_pid() {
#ifdef _MSC_VER
    return ::GetCurrentProcessId();
#else
    reurn ::getpid();
#endif
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

static void check_input(sol::state& lua) {
#ifdef WIN32
    if (_kbhit()) {
        char cur = _getch();
        if (cur == '\xE0' || cur == '\x0') {
            if (_kbhit()) {
                _getch();
                return;
            }
        }
        std::string code = "quanta.console(" + cur;
        lua.safe_script(code + ")");
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

void quanta_app::set_signal(uint32_t n) {
    uint32_t mask = 1 << n;
    m_signal |= mask;
}

void quanta_app::load_config(int argc, const char* argv[]) {
    sol::state lua;
    lua.open_libraries();
    lua.set("platform", get_platform());
    lua.set_function("set_env", set_env);
    if (argc > 1) {
        setenv("QUANTA_INDEX", "1", 1);
        //加载配置
        lua.script_file(argv[1]);
        //将启动参数转换成环境变量
        for (int i = 2; i < argc; ++i) {
            std::string argvi = argv[i];
            auto pos = argvi.find("=");
            if (pos != std::string::npos) {
                auto eval = argvi.substr(pos + 1);
                auto ekey = "QUANTA_" + argvi.substr(2, pos - 2);
                std::transform(ekey.begin(), ekey.end(), ekey.begin(), [](auto c) { return std::toupper(c); });
                setenv(ekey.c_str(), eval.c_str(), 1);
            }
        }
    }
}

void quanta_app::run(int argc, const char* argv[]) {
    sol::state lua;
    load_config(argc, argv);
    lua.open_libraries();
    sol::table quanta = lua.create_named_table("quanta");
    quanta.set("pid", get_pid());
    quanta.set("platform", get_platform());
    quanta.set_function("daemon", daemon);
    quanta.set_function("get_signal", [&]() { return m_signal; });
    quanta.set_function("set_signal", [&](int n) { set_signal(n); });
    quanta.set_function("ignore_signal", [](int n) { signal(n, SIG_IGN); });
    quanta.set_function("default_signal", [](int n) { signal(n, SIG_DFL); });
    quanta.set_function("register_signal", [](int n) { signal(n, on_signal); });

    auto sandbox = lua.script(std::string("require '") + getenv("QUANTA_SANDBOX") + "'");
    if (!sandbox.valid()) {
        sol::error err = sandbox;
        printf("load sandbox error: %s\n", err.what());
        exit(1);
    }
    auto entry = lua.script(std::string("require '") + getenv("QUANTA_ENTRY") + "'");
    if (!entry.valid()) {
        sol::error err = entry;
        printf("load sandbox error: %s\n", err.what());
        exit(1);
    }

    sol::function quanta_run = quanta["run"];
    while (quanta_run.valid()) {
        quanta_run();
        check_input(lua);
        quanta_run = quanta["run"];
    }
}
