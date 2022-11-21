#define LUA_LIB
#include "logger.h"

using namespace std;

namespace logger {

    luakit::lua_table open_lualog(lua_State* L) {
        luakit::kit_state kit_state(L);
        auto lualog = kit_state.new_table();
        lualog.new_enum("LOG_LEVEL",
            "INFO", log_level::LOG_LEVEL_INFO,
            "WARN", log_level::LOG_LEVEL_WARN,
            "DEBUG", log_level::LOG_LEVEL_DEBUG,
            "ERROR", log_level::LOG_LEVEL_ERROR,
            "FATAL", log_level::LOG_LEVEL_FATAL,
            "DUMP", log_level::LOG_LEVEL_DUMP
        );
        lualog.set_function("daemon", [](bool status) { get_logger()->daemon(status); });
        lualog.set_function("set_max_line", [](size_t line) { get_logger()->set_max_line(line); });
        lualog.set_function("set_clean_time", [](size_t time) { get_logger()->set_clean_time(time); });
        lualog.set_function("filter", [](int lv, bool on) { get_logger()->filter((log_level)lv, on); });
        lualog.set_function("is_filter", [](int lv) { return get_logger()->is_filter((log_level)lv); });
        lualog.set_function("del_dest", [](string feature) { get_logger()->del_dest(feature); });
        lualog.set_function("del_lvl_dest", [](int lv) { get_logger()->del_lvl_dest((log_level)lv); });
        lualog.set_function("add_lvl_dest", [](int lv) { return get_logger()->add_lvl_dest((log_level)lv); });
        lualog.set_function("ignore_prefix", [](string feature, bool prefix) { get_logger()->ignore_prefix(feature, prefix); });
        lualog.set_function("ignore_suffix", [](string feature, bool suffix) { get_logger()->ignore_suffix(feature, suffix); });
        lualog.set_function("add_dest", [](string feature, string log_path) { return get_logger()->add_dest(feature, log_path); });
        lualog.set_function("info", [](string msg, string tag, string feature) { get_logger()->output(log_level::LOG_LEVEL_INFO, msg, tag, feature); });
        lualog.set_function("warn", [](string msg, string tag, string feature) { get_logger()->output(log_level::LOG_LEVEL_WARN, msg, tag, feature); });
        lualog.set_function("dump", [](string msg, string tag, string feature) { get_logger()->output(log_level::LOG_LEVEL_DUMP, msg, tag, feature); });
        lualog.set_function("debug", [](string msg, string tag, string feature) { get_logger()->output(log_level::LOG_LEVEL_DEBUG, msg, tag, feature); });
        lualog.set_function("error", [](string msg, string tag, string feature) { get_logger()->output(log_level::LOG_LEVEL_ERROR, msg, tag, feature); });
        lualog.set_function("fatal", [](string msg, string tag, string feature) { get_logger()->output(log_level::LOG_LEVEL_FATAL, msg, tag, feature); });
        lualog.set_function("option", [](string log_path, string service, string index, rolling_type type) {
            get_logger()->option(log_path, service, index, type);
        });
        return lualog;
    }
}

extern "C" {
    LUALIB_API int luaopen_lualog(lua_State* L) {
        auto llog = logger::open_lualog(L);
        return llog.push_stack();
    }
}
