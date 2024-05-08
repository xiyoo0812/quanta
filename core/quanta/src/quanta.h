#pragma once
#include <map>

#include "logger.h"

class quanta_app final
{
public:
    void run();
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

private:
    uint64_t m_signal = 0;
    luakit::kit_state m_lua;
    std::map<std::string, std::string> m_environs;
};

extern quanta_app* g_app;
