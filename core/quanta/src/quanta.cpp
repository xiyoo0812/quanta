#include <signal.h>

#include "quanta.h"

#if defined(WIN32)
#include <conio.h>
#define getpid _getpid
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

static void check_input(luakit::kit_state* lua) {
#ifdef WIN32
    if (_kbhit()) {
        char cur = _getch();
        if (cur == '\xE0' || cur == '\x0') {
            if (_kbhit()) {
                _getch();
                return;
            }
        }
        lua->run_script(std::format("quanta.console({:d})", cur));
    }
#endif
}

quanta_app::~quanta_app() {
    if (m_lua) {
        delete m_lua;
        m_lua = nullptr;
    }
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

void quanta_app::set_env(const char* key, const char* value, int over) {
    if (over == 1 || !m_environs.contains(key)) {
        m_environs[key] = value;
    }
}

void quanta_app::add_path(const char* field, const char* path) {
    auto handle = m_environs.extract(field);
    if (handle.empty()) {
        m_environs[field] = path;
        m_lua->set_path(field, path);
        return;
    }
    auto& epath = handle.mapped();
    epath.append(path);
    m_environs.insert(std::move(handle));
    m_lua->set_path(field, epath.c_str());
}

bool quanta_app::setup(int argc, const char* argv[], lua_State* L) {
    if (L) {
        m_lua = new luakit::kit_state(L);
        m_lua->init_luakit(L);
    } else {
        m_lua = new luakit::kit_state();
    }
    //设置
    g_app = this;
    srand((unsigned)time(nullptr));
    //加载配置&&初始化
    return load(argc, argv) && init();
}

bool quanta_app::load(int argc, const char* argv[]) {
    //将启动参数转负责覆盖环境变量
    for (int i = 1; i < argc; ++i) {
        std::string argvi = argv[i];
        if (auto pos = argvi.find("="); pos != std::string::npos) {
            auto evalue = argvi.substr(pos + 1);
            auto ekey = std::format("QUANTA_{}", argvi.substr(2, pos - 2));
            std::transform(ekey.begin(), ekey.end(), ekey.begin(), [](auto c) { return std::toupper(c); });
            set_env(ekey.c_str(), evalue.c_str(), 1);
            continue;
        }
        if (i == 1){
            //加载LUA配置
            m_lua->set("platform", get_platform());
            m_lua->set_function("set_env", [&](const char* key, const char* value) { set_env(key, value, 1); });
            m_lua->set_function("add_path", [&](const char* field, const char* path) { add_path(field, path); });
            m_lua->set_function("set_path", [&](const char* field, const char* path) { m_lua->set_path(field, path); set_env(field, path, 1); });
            if (!m_lua->run_script(std::format("dofile('{}')", argv[1]), [&](std::string_view err) {
               exception_handler("load config {} err: {}", argv[1], err.data());
            })) return false;
        }
    }
    return true;
}

bool quanta_app::init() {
    //初始化lua
    auto tid = std::this_thread::get_id();
    auto quanta = m_lua->new_table("quanta");
    quanta.set("pid", ::getpid());
    quanta.set("master", true);
    quanta.set("thread", "quanta");
    quanta.set("environs", m_environs);
    quanta.set("tid", *(uint32_t*)&tid);
    quanta.set("platform", get_platform());
    quanta.set_function("daemon", [&]() { daemon(); });
    quanta.set_function("get_signal", [&]() { return m_signal; });
    quanta.set_function("set_signal", [&](int n, bool b) { set_signal(n, b); });
    quanta.set_function("ignore_signal", [](int n) { signal(n, SIG_IGN); });
    quanta.set_function("default_signal", [](int n) { signal(n, SIG_DFL); });
    quanta.set_function("register_signal", [](int n) { signal(n, on_signal); });
    quanta.set_function("getenv", [&](const char* key) { return get_env(key); });
    quanta.set_function("setenv", [&](const char* key, const char* value) { return set_env(key, value, 1); });
    auto sandbox = get_env("QUANTA_SANDBOX");
    if (sandbox) {
        if (!m_lua->run_script(std::format("require '{}'", sandbox), [&](std::string_view err) {
            exception_handler("load sandbox err: {}", err);
        })) return false;
    }
    auto entry = get_env("QUANTA_ENTRY");
    if  (!entry) {
        exception_handler("load entry err: {}", "entry not found");
        return false;
    }
    if (!m_lua->run_script(std::format("require '{}'", entry), [&](std::string_view err) {
        exception_handler("load entry {} err: {}", entry, err);
    })) return false;
    return true;
}

void quanta_app::run() {
    auto quanta = m_lua->get<luakit::lua_table>("quanta");
    while (quanta.get_function("run")) {
        quanta.call();
#ifdef WIN32
        check_input(m_lua);
#endif
    };
}

bool quanta_app::step() {
    auto quanta = m_lua->get<luakit::lua_table>("quanta");
    if (quanta.get_function("run")) {
        quanta.call();
        return true;
    }
    return false;
}