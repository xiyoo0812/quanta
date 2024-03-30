#include <locale>
#include <stdlib.h>
#if defined(__ORBIS__) || defined(__PROSPERO__)
#include <sys/signal.h>
#else
#include <signal.h>
#endif
#include <functional>
#include "quanta.h"

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

quanta_app::quanta_app() {
    mz_zip_zero_struct(&m_archive);
}

quanta_app::~quanta_app() {
    if (m_archive.m_pState){
        mz_zip_reader_end(&m_archive);
        mz_zip_zero_struct(&m_archive);
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

void quanta_app::initzip(const char* zfile) {
    memset(&m_archive, 0, sizeof(m_archive));
    mz_zip_reader_init_file(&m_archive, zfile, 0);
    m_lua.set_searchers([&](lua_State* L) {
        const char* fname = luaL_checkstring(L, 1);
        int index = find_zip_file(L, fname);
        if (index < 0) {
            lua_pushstring(L, fmt::format("file {} not found in zip!", fname).c_str());
            return 1;
        }
        if (load_zip_data(L, fname, index) == LUA_OK) {
            lua_pushstring(L, fname);  /* will be 2nd argument to module */
            return 2;  /* return open function and file name */
        }
        return luaL_error(L, "error loading module '%s' from file '%s':\n\t%s", lua_tostring(L, 1), fname, lua_tostring(L, -1));
    });
    m_lua.set_function("dofile", [&](lua_State* L) {
        const char* fname = luaL_optstring(L, 1, NULL);
        lua_settop(L, 1);
        if (load_zip_file(L) != LUA_OK) {
            return lua_error(L);
        }
        auto kf = [](lua_State* L, int d1, lua_KContext d2) { return lua_gettop(L) - 1; };
        lua_callk(L, 0, LUA_MULTRET, 0, kf);
        return kf(L, 0, 0);
    });
    m_lua.set_function("loadfile", [&](lua_State* L) {
        int env = (!lua_isnone(L, 3) ? 3 : 0);  /* 'env' index or 0 if no 'env' */
        if (load_zip_file(L) == LUA_OK) {
            if (env != 0) {  /* 'env' parameter? */
                lua_pushvalue(L, env);  /* environment for loaded function */
                if (!lua_setupvalue(L, -2, 1))  /* set it as 1st upvalue */
                    lua_pop(L, 1);  /* remove 'env' if not used by previous call */
            }
            return 1;
        }
        //error(message is on top of the stack)* /
        lua_pushnil(L);
        lua_insert(L, -2);
        return 2;
    });
}

int quanta_app::find_zip_file(lua_State* L, std::string filename) {
    size_t start_pos = 0;
    luakit::lua_guard g(L);
    lua_getglobal(L, LUA_LOADLIBNAME);
    lua_getfield(L, -1, "path");
    std::string path = lua_tostring(L, -1);
    while ((start_pos = filename.find(".", start_pos)) != std::string::npos) {
        filename.replace(start_pos, strlen("."), LUA_DIRSEP);
        start_pos += strlen(LUA_DIRSEP);
    }
    start_pos = 0;
    while ((start_pos = path.find(LUA_PATH_MARK, start_pos)) != std::string::npos) {
        path.replace(start_pos, strlen(LUA_PATH_MARK), filename);
        start_pos += filename.size();
    }
    start_pos = 0;
    while ((start_pos = path.find(LUA_DIRSEP, start_pos)) != std::string::npos) {
        path.replace(start_pos, strlen(LUA_DIRSEP), "/");
        start_pos += strlen("/");
    }
    size_t cur = 0, pos = 0;
    while ((pos = path.find(LUA_PATH_SEP, cur)) != std::string::npos) {
        std::string sub = path.substr(cur, pos - cur);
        int index = mz_zip_reader_locate_file(&m_archive, sub.c_str(), nullptr, MZ_ZIP_FLAG_CASE_SENSITIVE);
        if (index > 0) {
            return index;
        }
        cur = pos + strlen(LUA_PATH_SEP);
    }
    if (path.size() > cur) {
        std::string sub = path.substr(cur);
        return mz_zip_reader_locate_file(&m_archive, sub.c_str(), nullptr, MZ_ZIP_FLAG_CASE_SENSITIVE);
    }
    return -1;
}

bool quanta_app::zip_exist(const char* fname) {
    return mz_zip_reader_locate_file(&m_archive, fname, nullptr, MZ_ZIP_FLAG_CASE_SENSITIVE) > 0;
}

int quanta_app::zip_load(lua_State* L) {
    const char* fname = luaL_optstring(L, 1, nullptr);
    int index = mz_zip_reader_locate_file(&m_archive, fname, nullptr, MZ_ZIP_FLAG_CASE_SENSITIVE);
    if (index <= 0) return 0;
    size_t size = 0;
    const char* data = (const char*)mz_zip_reader_extract_to_heap(&m_archive, index, &size, MZ_ZIP_FLAG_CASE_SENSITIVE);
    if (!data) return 0;
    lua_pushlstring(L, data, size);
    delete[] data;
    return 1;
}

int quanta_app::load_zip_file(lua_State* L) {
    const char* fname = luaL_optstring(L, 1, nullptr);
    int index = mz_zip_reader_locate_file(&m_archive, fname, nullptr, MZ_ZIP_FLAG_CASE_SENSITIVE);
    if (index <= 0) {
        lua_pushstring(L, fmt::format("file {} not found in zip!", fname).c_str());
        return LUA_ERRERR;
    }
    return load_zip_data(L, fname, index);
}

int quanta_app::load_zip_data(lua_State* L, const char* filename, int index) {
    size_t size = 0;
    const char* data = (const char*)mz_zip_reader_extract_to_heap(&m_archive, index, &size, MZ_ZIP_FLAG_CASE_SENSITIVE);
    if (!data) {
        lua_pushstring(L, "file read failed!");
        return LUA_ERRERR;
    }
    int status = luaL_loadbufferx(L, data, size, filename, luaL_optstring(L, 2, nullptr));
    delete[] data;
    return status;
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
            m_lua.set_function("init_zip", [&](std::string zfile) { return initzip(zfile.c_str()); });
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
    quanta.set("pid", ::getpid());
    quanta.set("title", "quanta");
    quanta.set("environs", m_environs);
    quanta.set("platform", get_platform());
    quanta.set_function("daemon", [&]() { daemon(); });
    quanta.set_function("get_signal", [&]() { return m_signal; });
    quanta.set_function("set_signal", [&](int n, bool b) { set_signal(n, b); });
    quanta.set_function("ignore_signal", [](int n) { signal(n, SIG_IGN); });
    quanta.set_function("default_signal", [](int n) { signal(n, SIG_DFL); });
    quanta.set_function("register_signal", [](int n) { signal(n, on_signal); });
    quanta.set_function("zload", [&](lua_State* L) { return zip_load(L); });
    quanta.set_function("zexist", [&](const char* fn) { return zip_exist(fn); });
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
    const char* env_include = get_env("QUANTA_INCLUDE");
    if (env_include) {
        m_lua.run_script(fmt::format("require '{}'", env_include), [&](std::string_view err) {
            exception_handler("load includes err: {}", err);
        });
    }
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

bool quanta_app::step() {
    auto quanta = m_lua.get<luakit::lua_table>("quanta");
    if (quanta.get_function("run")) {
        quanta.call([&](std::string_view err) {
            LOG_FATAL(fmt::format("quanta run err: {} ", err));
        });
        check_input(m_lua);
        return true;
    }
    logger::get_logger()->stop();
    return false;
}