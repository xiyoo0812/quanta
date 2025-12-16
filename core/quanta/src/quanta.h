#pragma once

#include "lua_kit.h"

class quanta_app final
{
public:
    ~quanta_app();
    
    void run();
    bool step();
    bool init();
    bool load(int argc, cpchar argv[]);
    void set_signal(uint32_t n, bool b = true);
    void add_path(cpchar field, cpchar path);
    void set_env(cpchar key, cpchar value, int over = 0);
    bool setup(int argc, cpchar argv[], lua_State* L = nullptr);

    luakit::kit_state* state() { return m_lua; };
    
    lua_State* L() { return m_lua->L();  }
    sstring last_error() { return m_error;  }

protected:
    cpchar get_env(cpchar key);
    template<typename... Args>
    void exception_handler(vstring msg, Args&&... args){
        m_error = std::vformat(msg, std::make_format_args(args...)).c_str();
        printf(m_error.c_str());
    }

private:
    sstring m_error = "";
    uint64_t m_signal = 0;
    luakit::kit_state* m_lua = nullptr;
    std::unordered_map<sstring, sstring> m_environs;
};

extern quanta_app* g_app;
