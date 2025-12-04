#pragma once
#include <array>

#include "lua_function.h"

namespace luakit {
    class lua_logger {
    public:
        void init(lua_State* L) { 
            m_L = L;
        }

        template <typename... Args>
        void output(const char* method, std::string_view fmt, Args&&... args) {
            lua_guard g(m_L);
            auto msg = std::vformat(fmt, std::make_format_args(args...));
            if (!call_global_function(m_L, method, nullptr, std::tie(), msg)) {
                printf(msg.c_str());
            }
        }

    private:
        lua_State* m_L = nullptr;
    };

    inline thread_local lua_logger glogger;

    inline lua_logger* get_logger() {
        return &glogger;
    }

}

#define LOG_WARN(fmt, ...)  luakit::get_logger()->output("warn", fmt, ##__VA_ARGS__)
#define LOG_DUMP(fmt, ...)  luakit::get_logger()->output("dump", fmt, ##__VA_ARGS__)
#define LOG_INFO(fmt, ...)  luakit::get_logger()->output("print", fmt, ##__VA_ARGS__)
#define LOG_DEBUG(fmt, ...) luakit::get_logger()->output("trace", fmt, ##__VA_ARGS__)
#define LOG_ERROR(fmt, ...) luakit::get_logger()->output("error", fmt, ##__VA_ARGS__)
#define LOG_FATAL(fmt, ...) luakit::get_logger()->output("fatal", fmt, ##__VA_ARGS__)
