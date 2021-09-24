#pragma once
#include <map>

#include "logger.h"
#include "sol/sol.hpp"

using environ_map = std::map<std::string, std::string>;

using namespace logger;
class quanta_app final
{
public:
    quanta_app() { }
    ~quanta_app() { }

    void run();
    void setup(int argc, const char* argv[]);
    void load(int argc, const char* argv[]);
    void set_signal(uint32_t n);

protected:
    void init_logger();
    void sol_exception_handler(std::string msg, sol::protected_function_result& result);

private:
    uint64_t m_signal = 0;
    environ_map m_environs;

    std::shared_ptr<log_service> m_logger;
};

extern quanta_app* g_app;
