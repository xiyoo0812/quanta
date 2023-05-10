#pragma once
#include <map>

#include "logger.h"

class quanta_app final
{
public:
    quanta_app() { }
    ~quanta_app() { }

    void run();
    void setup(int argc, const char* argv[]);
    void load(int argc, const char* argv[]);
    void set_signal(uint32_t n, bool b = true);

protected:
    void exception_handler(std::string msg, std::string& err);
    const char* get_env(const char* key);
    int set_env(lua_State* L);

private:
    uint64_t m_signal = 0;
    std::map<std::string, std::string> m_environs;
};

extern quanta_app* g_app;
