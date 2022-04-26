#include <locale>
#include <stdlib.h>
#include <signal.h>
#include <functional>
#include "quanta.h"

#include "lua_kit.h"
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

static int hash_code(lua_State* L) {
    size_t hcode = 0;
    int type = lua_type(L, 1);
    if (type == LUA_TNUMBER) {
        hcode = std::hash<int64_t>{}(lua_tointeger(L, 1));
    } else if (type == LUA_TSTRING) {
        hcode = std::hash<std::string>{}(lua_tostring(L, 1));
    } else {
        luaL_error(L, "hashkey only support number or string!");
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
    srand((unsigned)time(nullptr));
    //初始化日志
    m_logger = std::make_shared<log_service>();
    m_logger->start();
    //加载配置
    load(argc, argv);
    //运行
    run();
}

void quanta_app::exception_handler(std::string msg, std::string& err) {
    LOG_FATAL(m_logger) << msg << err;
    m_logger->stop();
#if WIN32
    _getch();
#endif
    exit(1);
}

const char* quanta_app::get_environ(std::string k) {
    auto iter = m_environs.find(k);
    if (iter == m_environs.end()) return nullptr;
    return iter->second.c_str();
}

void quanta_app::load(int argc, const char* argv[]) {
    //初始化lua
    luakit::kit_state lua;
    lua.set("platform", get_platform());
    //设置默认参数
    set_environ("QUANTA_SERVICE", "quanta");
    set_environ("QUANTA_INDEX", "1");
    //加载LUA配置
    lua.set_function("set_env", [&](std::string k, std::string v) { 
        m_environs[k] = v; 
    });
    lua.set_function("set_osenv", [&](std::string k, std::string v) {
        m_environs[k] = v;
        setenv(k.c_str(), v.c_str(), 1); 
    });
    lua.run_file(argv[1], [&](std::string err) {
        exception_handler("load config err: ", err);
    });
    //将启动参数转换成环境变量
    for (int i = 2; i < argc; ++i) {
        std::string argvi = argv[i];
        auto pos = argvi.find("=");
        if (pos != std::string::npos) {
            auto evalue = argvi.substr(pos + 1);
            auto ekey = fmt::format("QUANTA_{}", argvi.substr(2, pos - 2));
            std::transform(ekey.begin(), ekey.end(), ekey.begin(), [](auto c) { return std::toupper(c); });
            set_environ(ekey, evalue);
        }
    }
    lua.close();
}

void quanta_app::init_logger() {
    auto lgetenv = [&](std::string key, std::string def) { 
        auto value = get_environ(key);
        return value ? value : def;
    };
    std::string index = get_environ("QUANTA_INDEX");
    std::string service = get_environ("QUANTA_SERVICE");
    auto logpath = lgetenv("QUANTA_LOG_PATH", "./logs/");
    auto maxline = std::stoi(lgetenv("QUANTA_LOG_LINE", "100000"));
    auto rolltype = (logger::rolling_type)std::stoi(lgetenv("QUANTA_LOG_ROLL", "0"));
    m_logger->option(logpath, service, index, rolltype, maxline);
    m_logger->add_dest(service);
    if (std::stoi(lgetenv("QUANTA_DAEMON", "0"))) {
        quanta_daemon();
    }
}

void quanta_app::run() {
    init_logger();
    //初始化lua
    luakit::kit_state lua;
    lua.set("platform", get_platform());
    auto quanta = lua.new_table("quanta");
    quanta.set("pid", ::getpid());
    quanta.set("environs", m_environs);
    quanta.set("platform", get_platform());
    quanta.set_function("hash_code", hash_code);
    quanta.set_function("get_signal", [&]() { return m_signal; });
    quanta.set_function("set_signal", [&](int n) { set_signal(n); });
    quanta.set_function("get_logger", [&]() { return m_logger.get(); });
    quanta.set_function("ignore_signal", [](int n) { signal(n, SIG_IGN); });
    quanta.set_function("default_signal", [](int n) { signal(n, SIG_DFL); });
    quanta.set_function("register_signal", [](int n) { signal(n, on_signal); });
    quanta.set_function("getenv", [&](std::string k) { return get_environ(k); });
    quanta.set_function("setenv", [&](std::string k, std::string v) { m_environs[k] = v; });

    lua.run_script(fmt::format("require '{}'", get_environ("QUANTA_SANDBOX")), [&](std::string err) {
        exception_handler("load sandbox err: ", err);
    });
    lua.run_script(fmt::format("require '{}'", get_environ("QUANTA_ENTRY")), [&](std::string err) {
        exception_handler("load entry err: ", err);
    });
    while (quanta.get_function("run")) {
        quanta.call([&](std::string err) {
            exception_handler("quanta run err: ", err);
        });
        check_input(lua);
    }
    lua.close();
    m_logger->stop();
}
