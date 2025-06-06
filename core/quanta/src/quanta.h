#pragma once

#include "logger.h"

class quanta_app final
{
public:
    void run();
    bool init();
    bool step();
    void setup(int argc, const char* argv[]);
    void load(int argc, const char* argv[]);
    void set_signal(uint32_t n, bool b = true);
    void add_path(const char* field, const char* path);
    void set_env(const char* key, const char* value, int over = 0);
    void set_library() { m_process = false; }

    luakit::kit_state* state() { return &m_lua; };
    
    lua_State* L() { return m_lua.L();  }

protected:
    void exception_handler(std::string_view msg, std::string_view err);
    const char* get_env(const char* key);

private:
    bool m_process = true;
    uint64_t m_signal = 0;
    luakit::kit_state m_lua;
    std::unordered_map<std::string, std::string> m_environs;
};

extern quanta_app* g_app;
