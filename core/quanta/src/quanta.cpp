#include <locale>
#include <stdlib.h>
#include <functional>

#include "quanta.h"

#if defined(__ORBIS__) || defined(__PROSPERO__) || defined(__NINTENDO__)
#define _signal(s, t)
#else
#include <signal.h>
#define _signal signal
#endif

#if WIN32
#include <conio.h>
#include <windows.h>
int setenv(const char* k, const char* v, int o) {
    return _putenv_s(k, v);
}
#elif defined(__ORBIS__) || defined(__PROSPERO__)
#define setenv(k, v, o)
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
#elif defined(__ORBIS__)
    return "ps4";
#elif defined(__PROSPERO__)
    return "ps5";
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

void quanta_app::set_signal(uint32_t n, bool b) {
    uint32_t mask = 1 << n;
    if (b) {
        m_signal |= mask;
    } else {
        m_signal ^= mask;
    }
}

const char* quanta_app::get_env(const char* key) {
    auto it = m_environs.find(key);
    if (it != m_environs.end()) return it->second.c_str();
    return nullptr;
}

void quanta_app::set_env(std::string key, std::string value, int over) {
    if (over == 1 || m_environs.find(key) == m_environs.end()) {
        setenv(key.c_str(), value.c_str(), 1);
        m_environs[key] = value;
    }
}

void quanta_app::set_path(std::string field, std::string path) {
    set_env(field, path, 1);
#ifdef WIN32
    char workdir[MAX_PATH + 1];
    GetCurrentDirectory(sizeof(workdir), workdir);
    m_lua.set_path(field.c_str(), path.c_str(), workdir);
#else
    m_lua.set_path(field.c_str(), path.c_str(), nullptr);
#endif
}

void quanta_app::setup(int argc, const char* argv[]) {
    srand((unsigned)time(nullptr));
    //初始化日志
    logger::get_logger();
    //加载配置
    load(argc, argv);
    //设置
    g_app = this;
}

void quanta_app::exception_handler(std::string_view msg, std::string_view err) {
    LOG_FATAL(fmt::format(msg, err));
    std::this_thread::sleep_for(std::chrono::seconds(1));
    exit(1);
}

void quanta_app::load(int argc, const char* argv[]) {
    //设置默认参数
    set_env("QUANTA_SANDBOX", "sandbox", 1);
    //将启动参数转负责覆盖环境变量
    for (int i = 1; i < argc; ++i) {
        std::string argvi = argv[i];
        auto pos = argvi.find("=");
        if (pos != std::string::npos) {
            auto evalue = argvi.substr(pos + 1);
            auto ekey = fmt::format("QUANTA_{}", argvi.substr(2, pos - 2));
            std::transform(ekey.begin(), ekey.end(), ekey.begin(), [](auto c) { return std::toupper(c); });
            set_env(ekey.c_str(), evalue.c_str(), 1);
            continue;
        }
        if (i == 1){
            //加载LUA配置
            m_lua.set("platform", get_platform());
            m_lua.set_function("set_env", [&](std::string key, std::string value) { return set_env(key, value, 1); });
            m_lua.set_function("set_path", [&](std::string field, std::string path) { return set_path(field, path); });
            m_lua.run_script(fmt::format("dofile('{}')", argv[1]), [&](std::string_view err) {
                exception_handler("load sandbox err: {}", err);
            });
        }
    }
}

luakit::lua_table quanta_app::init() {
    //初始化lua
    auto quanta = m_lua.new_table("quanta");
    auto tid = std::this_thread::get_id();
    quanta.set("pid", ::getpid());
    quanta.set("title", "quanta");
    quanta.set("environs", m_environs);
    quanta.set("tid", *(uint32_t*)&tid);
    quanta.set("platform", get_platform());
    quanta.set_function("daemon", [&]() { daemon(); });
    quanta.set_function("get_signal", [&]() { return m_signal; });
    quanta.set_function("set_signal", [&](int n, bool b) { set_signal(n, b); });
    quanta.set_function("ignore_signal", [](int n) { _signal(n, SIG_IGN); });
    quanta.set_function("default_signal", [](int n) { _signal(n, SIG_DFL); });
    quanta.set_function("register_signal", [](int n) { _signal(n, on_signal); });
    quanta.set_function("getenv", [&](const char* key) { return get_env(key); });
    quanta.set_function("setenv", [&](std::string key, std::string value) { return set_env(key, value, 1); });

    const char* env_log_path = get_env("QUANTA_LOG_PATH");
    if (env_log_path) {
        const char* env_index = get_env("QUANTA_INDEX");
        const char* env_service = get_env("QUANTA_SERVICE");
        logger::get_logger()->option(env_log_path, env_service, env_index);
    }
    m_lua.run_script(fmt::format("require '{}'", get_env("QUANTA_SANDBOX")), [&](std::string_view err) {
        exception_handler("load sandbox err: {}", err);
    });
    m_lua.run_script(fmt::format("require '{}'", get_env("QUANTA_ENTRY")), [&](std::string_view err) {
        exception_handler("load entry err: {}", err);
    });
    return quanta;
}

void quanta_app::run() {
    auto quanta = init();
    while (quanta.get_function("run")) {
        quanta.call([&](std::string_view err) {
            LOG_FATAL(fmt::format("quanta run err: {} ", err));
        });
        check_input(m_lua);
    };
    logger::get_logger()->stop();
}
