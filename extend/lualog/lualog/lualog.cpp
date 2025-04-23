#define LUA_LIB
#include "logger.h"

using namespace std;
using namespace luakit;


namespace logger {

    thread_local std::shared_ptr<log_agent> s_agent = make_shared<log_agent>();
    static std::shared_ptr<log_service> s_logger = make_shared<log_service>();

    const int LOG_FLAG_FORMAT = 1;
    const int LOG_FLAG_PRETTY = 2;
    const int LOG_FLAG_MONITOR = 4;
    string read_args(lua_State* L, int flag, int index) {
        switch (lua_type(L, index)) {
        case LUA_TNIL: return "nil";
        case LUA_TTHREAD: return "thread";
        case LUA_TFUNCTION: return "function";
        case LUA_TUSERDATA:  return "userdata";
        case LUA_TLIGHTUSERDATA: return "userdata";
        case LUA_TBOOLEAN: return lua_toboolean(L, index) ? "true" : "false";
        case LUA_TSTRING: {
            size_t len;
            const char* buf = lua_tolstring(L, index, &len);
            return string(buf, len);
        }
        case LUA_TTABLE:
            if ((flag & LOG_FLAG_FORMAT) == LOG_FLAG_FORMAT) {
                auto buf = luakit::get_buff();
                buf->clean();
                serialize_one(L, buf, index, 1, (flag & LOG_FLAG_PRETTY) == LOG_FLAG_PRETTY);
                return string((char*)buf->head(), buf->size());
            }
            return luaL_tolstring(L, index, nullptr);
        case LUA_TNUMBER:
            if (lua_isinteger(L, index)) {
                return fmt::format("{}", lua_tointeger(L, index));
            }
            return fmt::format("{}", lua_tonumber(L, index));
        }
        return "unsuppert data type";
    }

    int zformat(lua_State* L, log_level lvl, cpchar tag, cpchar feature, int flag, sstring&& msg) {
        if ((flag & LOG_FLAG_MONITOR) == LOG_FLAG_MONITOR) {
            lua_pushlstring(L, msg.c_str(), msg.size());
            s_agent->output(lvl, std::move(msg), tag, feature);
            return 1;
        }
        s_agent->output(lvl, std::move(msg), tag, feature);
        return 0;
    }

    template<size_t... integers>
    int tformat(lua_State* L, log_level lvl, cpchar tag, cpchar feature, int flag, cpchar vfmt, std::index_sequence<integers...>&&) {
        try {
            auto msg = fmt::format(vfmt, read_args(L, flag, integers + 6)...);
            return zformat(L, lvl, tag, feature, flag, std::move(msg));
        } catch (const exception& e) {
            luaL_error(L, "log format failed: %s!", e.what());
        }
        return 0;
    }

    template<size_t... integers>
    int fformat(lua_State* L, int flag, cpchar vfmt, std::index_sequence<integers...>&&) {
        try {
            auto msg = fmt::format(vfmt, read_args(L, flag, integers + 2)...);
            lua_pushlstring(L, msg.c_str(), msg.size());
            return 1;
        } catch (const exception& e) {
            luaL_error(L, "log format failed: %s!", e.what());
        }
        return 0;
    }

    luakit::lua_table open_lualog(lua_State* L) {
        luakit::kit_state kit_state(L);
        auto lualog = kit_state.new_table("log");
        lualog.new_enum("LOG_LEVEL",
            "INFO", log_level::LOG_LEVEL_INFO,
            "WARN", log_level::LOG_LEVEL_WARN,
            "DUMP", log_level::LOG_LEVEL_DUMP,
            "DEBUG", log_level::LOG_LEVEL_DEBUG,
            "ERROR", log_level::LOG_LEVEL_ERROR,
            "FATAL", log_level::LOG_LEVEL_FATAL
        );
        lualog.new_enum("LOG_FLAG",
            "NULL", 0,
            "FORMAT", LOG_FLAG_FORMAT,
            "PRETTY", LOG_FLAG_PRETTY,
            "MONITOR", LOG_FLAG_MONITOR
        );
        lualog.set_function("print", [](lua_State* L) {
            log_level lvl = (log_level)lua_tointeger(L, 1);
            if (s_agent->is_filter(lvl)) return 0;
            size_t flag = lua_tointeger(L, 2);
            cpchar tag = lua_to_native<cpchar>(L, 3);
            cpchar feature = lua_to_native<cpchar>(L, 4);
            cpchar vfmt = lua_to_native<cpchar>(L, 5);
            int arg_num = lua_gettop(L) - 5;
            switch (arg_num) {
            case 0: return zformat(L, lvl, tag, feature, flag, string(vfmt));
            case 1: return tformat(L, lvl, tag, feature, flag, vfmt, make_index_sequence<1>{});
            case 2: return tformat(L, lvl, tag, feature, flag, vfmt, make_index_sequence<2>{});
            case 3: return tformat(L, lvl, tag, feature, flag, vfmt, make_index_sequence<3>{});
            case 4: return tformat(L, lvl, tag, feature, flag, vfmt, make_index_sequence<4>{});
            case 5: return tformat(L, lvl, tag, feature, flag, vfmt, make_index_sequence<5>{});
            case 6: return tformat(L, lvl, tag, feature, flag, vfmt, make_index_sequence<6>{});
            case 7: return tformat(L, lvl, tag, feature, flag, vfmt, make_index_sequence<7>{});
            case 8: return tformat(L, lvl, tag, feature, flag, vfmt, make_index_sequence<8>{});
            case 9: return tformat(L, lvl, tag, feature, flag, vfmt, make_index_sequence<9>{});
            case 10: return tformat(L, lvl, tag, feature, flag, vfmt, make_index_sequence<10>{});
            default: luaL_error(L, "print args is more than 10!"); break;
            }
            return 0;
        });
        lualog.set_function("format", [](lua_State* L) {
            cpchar vfmt = lua_to_native<cpchar>(L, 1);
            int arg_num = lua_gettop(L) - 1;
            switch (arg_num) {
            case 0: lua_pushstring(L, vfmt); return 1;
            case 1: return fformat(L, LOG_FLAG_FORMAT, vfmt, make_index_sequence<1>{});
            case 2: return fformat(L, LOG_FLAG_FORMAT, vfmt, make_index_sequence<2>{});
            case 3: return fformat(L, LOG_FLAG_FORMAT, vfmt, make_index_sequence<3>{});
            case 4: return fformat(L, LOG_FLAG_FORMAT, vfmt, make_index_sequence<4>{});
            case 5: return fformat(L, LOG_FLAG_FORMAT, vfmt, make_index_sequence<5>{});
            case 6: return fformat(L, LOG_FLAG_FORMAT, vfmt, make_index_sequence<6>{});
            case 7: return fformat(L, LOG_FLAG_FORMAT, vfmt, make_index_sequence<7>{});
            case 8: return fformat(L, LOG_FLAG_FORMAT, vfmt, make_index_sequence<8>{});
            case 9: return fformat(L, LOG_FLAG_FORMAT, vfmt, make_index_sequence<9>{});
            case 10: return fformat(L, LOG_FLAG_FORMAT, vfmt, make_index_sequence<10>{});
            default: luaL_error(L, "format args is more than 10!"); break;
            }
            return 0;
        });

        lualog.set_function("daemon", [](bool status) { s_logger->daemon(status); });
        lualog.set_function("set_max_size", [](size_t size) { s_logger->set_max_size(size); });
        lualog.set_function("set_clean_time", [](size_t time) { s_logger->set_clean_time(time); });
        lualog.set_function("attach", []() { s_agent->attach(s_logger->weak_from_this()); });
        lualog.set_function("filter", [](int lv, bool on) { s_agent->filter((log_level)lv, on); });
        lualog.set_function("is_filter", [](int lv) { return s_agent->is_filter((log_level)lv); });
        lualog.set_function("del_dest", [](cpchar feature) { s_logger->del_dest(feature); });
        lualog.set_function("del_lvl_dest", [](int lv) { s_logger->del_lvl_dest((log_level)lv); });
        lualog.set_function("add_lvl_dest", [](int lv) { return s_logger->add_lvl_dest((log_level)lv); });
        lualog.set_function("set_rolling_type", [](rolling_type type) { s_logger->set_rolling_type(type); });
        lualog.set_function("ignore_prefix", [](cpchar feature, bool prefix) { s_logger->ignore_prefix(feature, prefix); });
        lualog.set_function("ignore_suffix", [](cpchar feature, bool suffix) { s_logger->ignore_suffix(feature, suffix); });
        lualog.set_function("add_dest", [](cpchar feature) { return s_logger->add_dest(feature); });
        lualog.set_function("add_file_dest", [](cpchar feature, cpchar fname) { return s_logger->add_file_dest(feature, fname); });
        lualog.set_function("set_dest_clean_time", [](cpchar feature, size_t time) { s_logger->set_dest_clean_time(feature, time); });
        lualog.set_function("option", [](cpchar log_path, cpchar service, cpchar index) { s_logger->option(log_path, service, index); });
        return lualog;
    }
}

extern "C" {
    LUALIB_API int luaopen_lualog(lua_State* L) {
        auto llog = logger::open_lualog(L);
        return llog.push_stack();
    }

    LUALIB_API void option_logger(cpchar log_path, cpchar service, cpchar index) {
        logger::s_logger->option(log_path, service, index);
    }
    
    LUALIB_API void output_logger(logger::log_level level, sstring&& msg, cpchar tag, cpchar feature, cpchar source, int line){
        logger::s_agent->output(level, std::move(msg), tag, feature, source, line);
    }
}
