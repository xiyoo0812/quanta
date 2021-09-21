#pragma once

extern "C"
{
    #include "lua.h"
    #include "lualib.h"
    #include "lauxlib.h"
}

class quanta_app final
{
public:
    quanta_app() { }
    ~quanta_app() { }
    void set_signal(uint32_t n);
    void run(int argc, const char* argv[]);

protected:
    void load_config(int argc, const char* argv[]);

private:
    uint64_t m_signal = 0;
};

extern quanta_app* g_app;
