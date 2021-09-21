#pragma once

class quanta_app final
{
public:
    quanta_app() { }
    ~quanta_app() { }
    void set_signal(uint32_t n);
    void run(int argc, const char* argv[]);

private:
    uint64_t m_signal = 0;
};

extern quanta_app* g_app;
