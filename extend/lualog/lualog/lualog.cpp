#define LUA_LIB
#include "logger.h"

using namespace std;
using namespace luakit;

namespace logger {

    thread_local luabuf* td_buffer = nullptr;
    
    const int LOG_FLAG_FORMAT   = 1;
    const int LOG_FLAG_PRETTY   = 2;
    const int LOG_FLAG_MONITOR = 4;

    string read_args(lua_State* L, int flag, int index) {
        switch (lua_type(L, index)) {
        case LUA_TNIL: return "nil";
        case LUA_TTHREAD: return "thread";
        case LUA_TFUNCTION: return "function";
        case LUA_TUSERDATA:  return "userdata";
        case LUA_TLIGHTUSERDATA: return "userdata";
        case LUA_TSTRING: return lua_tostring(L, index);
        case LUA_TBOOLEAN: return lua_toboolean(L, index) ? "true" : "false";
        case LUA_TTABLE:
            if ((flag & LOG_FLAG_FORMAT) == LOG_FLAG_FORMAT) {
                td_buffer->clean();
                serialize_one(L, td_buffer, index, 1, (flag & LOG_FLAG_PRETTY) == LOG_FLAG_PRETTY);
                return string((char*)td_buffer->head(), td_buffer->size());
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
            get_logger()->output(lvl, std::move(msg), tag, feature);
            return 1;
        }
        get_logger()->output(lvl, std::move(msg), tag, feature);
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
            auto msg = fmt::format(vfmt, read_args(L, flag, integers + 3)...);
            lua_pushlstring(L, msg.c_str(), msg.size());
            return 1;
        } catch (const exception& e) {
            luaL_error(L, "log format failed: %s!", e.what());
        }
        return 0;
    }

    luakit::lua_table open_lualog(lua_State* L) {
        luakit::kit_state kit_state(L);
        td_buffer = kit_state.get_buff();
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
            if (get_logger()->is_filter(lvl)) return 0;
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
            size_t flag = lua_tointeger(L, 2);
            int arg_num = lua_gettop(L) - 2;
            switch (arg_num) {
            case 0: lua_pushstring(L, vfmt); return 1;
            case 1: return fformat(L, flag, vfmt, make_index_sequence<1>{});
            case 2: return fformat(L, flag, vfmt, make_index_sequence<2>{});
            case 3: return fformat(L, flag, vfmt, make_index_sequence<3>{});
            case 4: return fformat(L, flag, vfmt, make_index_sequence<4>{});
            case 5: return fformat(L, flag, vfmt, make_index_sequence<5>{});
            case 6: return fformat(L, flag, vfmt, make_index_sequence<6>{});
            case 7: return fformat(L, flag, vfmt, make_index_sequence<7>{});
            case 8: return fformat(L, flag, vfmt, make_index_sequence<8>{});
            case 9: return fformat(L, flag, vfmt, make_index_sequence<9>{});
            case 10: return fformat(L, flag, vfmt, make_index_sequence<10>{});
            default: luaL_error(L, "format args is more than 10!"); break;
            }
            return 0;
        });
        
        lualog.set_function("daemon", [](bool status) { get_logger()->daemon(status); });
        lualog.set_function("set_max_line", [](size_t line) { get_logger()->set_max_line(line); });
        lualog.set_function("set_clean_time", [](size_t time) { get_logger()->set_clean_time(time); });
        lualog.set_function("filter", [](int lv, bool on) { get_logger()->filter((log_level)lv, on); });
        lualog.set_function("is_filter", [](int lv) { return get_logger()->is_filter((log_level)lv); });
        lualog.set_function("del_dest", [](cpchar feature) { get_logger()->del_dest(feature); });
        lualog.set_function("del_lvl_dest", [](int lv) { get_logger()->del_lvl_dest((log_level)lv); });
        lualog.set_function("add_lvl_dest", [](int lv) { return get_logger()->add_lvl_dest((log_level)lv); });
        lualog.set_function("set_rolling_type", [](rolling_type type) { get_logger()->set_rolling_type(type); });
        lualog.set_function("ignore_prefix", [](cpchar feature, bool prefix) { get_logger()->ignore_prefix(feature, prefix); });
        lualog.set_function("ignore_suffix", [](cpchar feature, bool suffix) { get_logger()->ignore_suffix(feature, suffix); });
        lualog.set_function("add_dest", [](cpchar feature) { return get_logger()->add_dest(feature); });
        lualog.set_function("add_file_dest", [](cpchar feature, cpchar fname) { return get_logger()->add_file_dest(feature, fname); });
        lualog.set_function("set_dest_clean_time", [](cpchar feature, size_t time) { get_logger()->set_dest_clean_time(feature, time); });
        lualog.set_function("option", [](cpchar log_path, cpchar service, cpchar index) { get_logger()->option(log_path, service, index); });
        return lualog;
    }
}

extern "C" {
    LUALIB_API int luaopen_lualog(lua_State* L) {
        auto llog = logger::open_lualog(L);
        return llog.push_stack();
    }
}
