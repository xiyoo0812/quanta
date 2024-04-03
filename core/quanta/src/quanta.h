#pragma once
#include <map>

#include "logger.h"
#include "miniz.h"

class quanta_app final
{
public:
    quanta_app();
    ~quanta_app();

    void run();
    bool step();
    bool initzip(const char* zfile);
    void setup(int argc, const char* argv[]);
    void load(int argc, const char* argv[]);
    void set_signal(uint32_t n, bool b = true);
    void set_env(std::string key, std::string value, int over = 0);

    luakit::lua_table init();
    lua_State* L() { return m_lua.L();  }

protected:
    void exception_handler(std::string_view msg, std::string_view err);
    void set_path(std::string field, std::string path);
    const char* get_env(const char* key);

    int zip_load(lua_State* L);
    bool zip_exist(const char* fname);

    int load_zip_file(lua_State* L);
    int find_zip_file(lua_State* L, std::string filename);
    int load_zip_data(lua_State* L, const char* filename, int index);

private:
    uint64_t m_signal = 0;
    luakit::kit_state m_lua;
    mz_zip_archive m_archive;
    std::map<std::string, std::string> m_environs;
};

extern quanta_app* g_app;
