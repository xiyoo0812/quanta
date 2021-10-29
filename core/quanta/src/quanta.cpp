#include <locale>
#include <stdlib.h>
#include <signal.h>
#include <functional>
#include "quanta.h"

extern "C" {
    #include "lua.h"
    #include "lauxlib.h"
}

#include <fmt/core.h>

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

static int quanta_daemon() {
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
        lua.script(fmt::format("quanta.console({:d})", cur));
    }
#endif
}

static int hash_code(lua_State* L) {
    size_t hcode = 0;
    if (lua_type(L, 1) == LUA_TNUMBER) {
        hcode = std::hash<int64_t>{}(lua_tointeger(L, 1));
    } else {
        hcode = std::hash<std::string>{}(lua_tostring(L, 1));
    }
    size_t mod = luaL_optinteger(L, 2, 0);
    if (mod > 0) {
        hcode = (hcode % mod) + 1;
    }
    lua_pushinteger(L, hcode);
    return 1;
}

void quanta_app::set_signal(uint32_t n) {
    uint32_t mask = 1 << n;
    m_signal |= mask;
}

void quanta_app::setup(int argc, const char* argv[]) {
    //初始化日志
    m_logger = std::make_shared<log_service>();
    m_logger->start();
    //加载配置
    load(argc, argv);
    //运行
    run();
}

void quanta_app::sol_exception_handler(std::string msg, sol::protected_function_result& result) {
    sol::error err = result;
    LOG_FATAL(m_logger) << msg << err.what();
    m_logger->stop();
#if WIN32
    _getch();
#endif
    exit(1);
}

void quanta_app::load(int argc, const char* argv[]) {
    sol::state lua;
    lua.open_libraries();
    lua.set("platform", get_platform());
    //定义函数
    auto lsetenv = [&](std::string k, std::string v) { 
        m_environs[k] = v;
        setenv(k.c_str(), v.c_str(), 1);
    };
    lua.set_function("set_env", lsetenv);
    //设置默认参数
    lsetenv("QUANTA_SERVICE", "quanta");
    lsetenv("QUANTA_INDEX", "1");
    //加载LUA配置
    lua.safe_script_file(argv[1], [&](lua_State*, sol::protected_function_result result) {
        sol_exception_handler("load config err: ", result);
        return result;
    });
    //将启动参数转换成环境变量
    for (int i = 2; i < argc; ++i) {
        std::string argvi = argv[i];
        auto pos = argvi.find("=");
        if (pos != std::string::npos) {
            auto evalue = argvi.substr(pos + 1);
            auto ekey = fmt::format("QUANTA_{}", argvi.substr(2, pos - 2));
            std::transform(ekey.begin(), ekey.end(), ekey.begin(), [](auto c) { return std::toupper(c); });
            lsetenv(ekey, evalue);
        }
    }
}

void quanta_app::init_logger() {
    auto lgetenv = [](std::string key, std::string def) { 
        auto value = getenv(key.c_str());
        return value ? value : def;
    };
    auto index = getenv("QUANTA_INDEX");
    auto service = getenv("QUANTA_SERVICE");
    auto logname = fmt::format("{}-{}", service, index);
    auto maxline = std::stoi(lgetenv("QUANTA_LOG_LINE", "100000"));
    auto logpath = fmt::format("{}/{}/", lgetenv("QUANTA_LOG_PATH", "./logs/"), service);
    auto rolltype = (logger::rolling_type)std::stoi(lgetenv("QUANTA_LOG_ROLL", "0"));
    m_logger->add_dest(logpath, logname, rolltype, maxline);
    if (std::stoi(lgetenv("QUANTA_DAEMON", "0"))) {
        quanta_daemon();
    }
}

void quanta_app::run() {
    init_logger();
    sol::state lua;
    lua.open_libraries();
    sol::table quanta = lua.create_named_table("quanta");
    quanta.set("pid", ::getpid());
    quanta.set("logger", m_logger);
    quanta.set("platform", get_platform());
    quanta.set("environs", sol::as_table(quanta_app::m_environs));
    quanta.set_function("hash_code", hash_code);
    quanta.set_function("get_signal", [&]() { return m_signal; });
    quanta.set_function("set_signal", [&](int n) { set_signal(n); });
    quanta.set_function("ignore_signal", [](int n) { signal(n, SIG_IGN); });
    quanta.set_function("default_signal", [](int n) { signal(n, SIG_DFL); });
    quanta.set_function("register_signal", [](int n) { signal(n, on_signal); });

    lua.safe_script(fmt::format("require '{}'", getenv("QUANTA_SANDBOX")), [&](lua_State*, sol::protected_function_result result) {
        sol_exception_handler("load sandbox err: ", result);
        return result;
    });
    lua.safe_script(fmt::format("require '{}'", getenv("QUANTA_ENTRY")), [&](lua_State*, sol::protected_function_result result) {
        sol_exception_handler("load entry err: ", result);
        return result;
    });
    sol::function quanta_run = quanta["run"];
    while (quanta_run.valid()) {
        quanta_run();
        check_input(lua);
        quanta_run = quanta["run"];
    }
    m_logger->stop();
}
