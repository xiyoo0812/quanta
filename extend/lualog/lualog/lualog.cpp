#define LUA_LIB
#include "logger.h"

namespace logger {

    luakit::lua_table open_lualog(lua_State* L) {
        luakit::kit_state kit_state(L);
        auto lualog = kit_state.new_table();
        lualog.new_enum("LOG_LEVEL",
            "INFO", log_level::LOG_LEVEL_INFO,
            "WARN", log_level::LOG_LEVEL_WARN,
            "DUMP", log_level::LOG_LEVEL_DUMP,
            "DEBUG", log_level::LOG_LEVEL_DEBUG,
            "ERROR", log_level::LOG_LEVEL_ERROR,
            "FATAL", log_level::LOG_LEVEL_FATAL
        );
        lualog.set_function("daemon", [](bool status) { get_logger()->daemon(status); });
        lualog.set_function("set_max_line", [](size_t line) { get_logger()->set_max_line(line); });
        lualog.set_function("set_clean_time", [](size_t time) { get_logger()->set_clean_time(time); });
        lualog.set_function("filter", [](int lv, bool on) { get_logger()->filter((log_level)lv, on); });
        lualog.set_function("is_filter", [](int lv) { return get_logger()->is_filter((log_level)lv); });
        lualog.set_function("del_dest", [](vstring feature) { get_logger()->del_dest(feature); });
        lualog.set_function("del_lvl_dest", [](int lv) { get_logger()->del_lvl_dest((log_level)lv); });
        lualog.set_function("add_lvl_dest", [](int lv) { return get_logger()->add_lvl_dest((log_level)lv); });
        lualog.set_function("set_rolling_type", [](rolling_type type) { get_logger()->set_rolling_type(type); });
        lualog.set_function("ignore_prefix", [](vstring feature, bool prefix) { get_logger()->ignore_prefix(feature, prefix); });
        lualog.set_function("ignore_suffix", [](vstring feature, bool suffix) { get_logger()->ignore_suffix(feature, suffix); });
        lualog.set_function("add_dest", [](vstring feature, vstring log_path) { return get_logger()->add_dest(feature, log_path); });
        lualog.set_function("add_file_dest", [](vstring feature, vstring fname) { return get_logger()->add_file_dest(feature, fname); });
        lualog.set_function("set_dest_clean_time", [](vstring feature, size_t time) { get_logger()->set_dest_clean_time(feature, time); });
        lualog.set_function("info", [](vstring msg, vstring tag, vstring feature) { get_logger()->output(log_level::LOG_LEVEL_INFO, msg, tag, feature); });
        lualog.set_function("warn", [](vstring msg, vstring tag, vstring feature) { get_logger()->output(log_level::LOG_LEVEL_WARN, msg, tag, feature); });
        lualog.set_function("dump", [](vstring msg, vstring tag, vstring feature) { get_logger()->output(log_level::LOG_LEVEL_DUMP, msg, tag, feature); });
        lualog.set_function("debug", [](vstring msg, vstring tag, vstring feature) { get_logger()->output(log_level::LOG_LEVEL_DEBUG, msg, tag, feature); });
        lualog.set_function("error", [](vstring msg, vstring tag, vstring feature) { get_logger()->output(log_level::LOG_LEVEL_ERROR, msg, tag, feature); });
        lualog.set_function("fatal", [](vstring msg, vstring tag, vstring feature) { get_logger()->output(log_level::LOG_LEVEL_FATAL, msg, tag, feature); });
        lualog.set_function("option", [](vstring log_path, vstring service, vstring index) { get_logger()->option(log_path, service, index); });
        return lualog;
    }
}

extern "C" {
    LUALIB_API int luaopen_lualog(lua_State* L) {
        auto llog = logger::open_lualog(L);
        return llog.push_stack();
    }
}
