#include <locale>
#include <stdlib.h>
#include <signal.h>
#include <functional>
#include "quanta.h"

#include "logger.h"
#include <fmt/core.h>

#if WIN32
#include <conio.h>
#include <windows.h>
int setenv(const char* k, const char* v, int o) {
    return _putenv_s(k, v);
}
#else
#include <fcntl.h>
#include <unistd.h>
#include <sys/stat.h>
#endif

using namespace logger;

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

static void daemon() {
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
}

static void check_input(luakit::kit_state& lua) {
#ifdef WIN32
    if (_kbhit()) {
        char cur = _getch();
        if (cur == '\xE0' || cur == '\x0') {
            if (_kbhit()) {
                _getch();
                return;
            }
        }
        lua.run_script(fmt::format("quanta.console({:d})", cur));
    }
#endif
}

void quanta_app::set_signal(uint32_t n) {
    uint32_t mask = 1 << n;
    m_signal |= mask;
}

const char* quanta_app::get_env(const char* key) {
    return getenv(key);
}

int quanta_app::set_env(lua_State* L) {
    const char* key = lua_tostring(L, 1);
    const char* value = lua_tostring(L, 2);
    if (getenv(key)){
        int overwrite = luaL_optinteger(L, 3, 0);
        if (overwrite || m_environs.find(key) != m_environs.end()) {
            setenv(key, value, 1);
        }
        return 0;
    }
    m_environs[key] = value;
    setenv(key, value, 1);
    return 0;
}

void quanta_app::setup(int argc, const char* argv[]) {
    srand((unsigned)time(nullptr));
    //初始化日志
    log_service::instance()->terminal();
    //加载配置
    load(argc, argv);
    //运行
    run();
}

void quanta_app::exception_handler(std::string msg, std::string& err) {
    PRINT_FATAL << msg << err;
#if WIN32
    _getch();
#endif
    exit(1);
}

void quanta_app::load(int argc, const char* argv[]) {
    //设置默认参数
    setenv("QUANTA_SANDBOX", "sandbox", 1);
    //将启动参数转负责覆盖环境变量
    for (int i = 1; i < argc; ++i) {
        std::string argvi = argv[i];
        auto pos = argvi.find("=");
        if (pos != std::string::npos) {
            auto evalue = argvi.substr(pos + 1);
            auto ekey = fmt::format("QUANTA_{}", argvi.substr(2, pos - 2));
            std::transform(ekey.begin(), ekey.end(), ekey.begin(), [](auto c) { return std::toupper(c); });
            setenv(ekey.c_str(), evalue.c_str(), 1);
            continue;
        }
        if (i == 1){
            //加载LUA配置
            luakit::kit_state lua;
            lua.set("platform", get_platform());
            lua.set_function("set_env", [&](lua_State* L) { return set_env(L); });
            lua.run_file(argv[1], [&](std::string err) {
                exception_handler("load lua config err: ", err);
            });
            lua.close();
        }
    }
}

void quanta_app::run() {
    //初始化lua
    luakit::kit_state lua;
    auto quanta = lua.new_table("quanta");
    quanta.set("pid", ::getpid());
    quanta.set("logtag", "[quanta]");
    quanta.set("environs", m_environs);
    quanta.set("platform", get_platform());
    quanta.set_function("daemon", [&]() { daemon(); });
    quanta.set_function("get_signal", [&]() { return m_signal; });
    quanta.set_function("set_signal", [&](int n) { set_signal(n); });
    quanta.set_function("ignore_signal", [](int n) { signal(n, SIG_IGN); });
    quanta.set_function("default_signal", [](int n) { signal(n, SIG_DFL); });
    quanta.set_function("register_signal", [](int n) { signal(n, on_signal); });
    quanta.set_function("getenv", [&](const char* key) { return get_env(key); });

    lua.run_script(fmt::format("require '{}'", get_env("QUANTA_SANDBOX")), [&](std::string err) {
        exception_handler("load sandbox err: ", err);
    });
    lua.run_script(fmt::format("require '{}'", get_env("QUANTA_ENTRY")), [&](std::string err) {
        exception_handler("load entry err: ", err);
    });
    const char* env_include = get_env("QUANTA_INCLUDE");
    if (env_include) {
        lua.run_script(fmt::format("require '{}'", env_include), [&](std::string err) {
            exception_handler("load includes err: ", err);
        });
    }
    while (quanta.get_function("run")) {
        quanta.call([&](std::string err) {
            PRINT_FATAL << "quanta run err: " << err;
        });
        check_input(lua);
    }
    lua.close();
}
