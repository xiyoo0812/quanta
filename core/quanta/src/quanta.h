#pragma once
#include <map>

#include "logger.h"

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
    const char* get_environ(std::string k);
    void set_environ(std::string k, std::string v) { m_environs[k] = v; }
    void exception_handler(std::string msg, std::string& err);

private:
    uint64_t m_signal = 0;
    environ_map m_environs;

    std::shared_ptr<log_service> m_logger;
};

extern quanta_app* g_app;
