#define LUA_LIB
#include "logger.h"

using namespace std;
using namespace luakit;

namespace logger {

    thread_local luabuf buf;
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
            if ((flag & 0x01) == 0x01) {
                buf.clean();
                serialize_one(L, &buf, index, 1, (flag & 0x02) == 0x02);
                return string((char*)buf.head(), buf.size());
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

    int zformat(lua_State* L, log_level lvl, cstring& tag, cstring& feature, cstring& msg) {
        if (lvl == log_level::LOG_LEVEL_FATAL) {
            lua_pushlstring(L, msg.c_str(), msg.size());
            get_logger()->output(lvl, msg, tag, feature);
            return 1;
        }
        get_logger()->output(lvl, msg, tag, feature);
        return 0;
    }

    template<size_t... integers>
    int tformat(lua_State* L, log_level lvl, cstring& tag, cstring& feature, int flag, vstring vfmt, std::index_sequence<integers...>&&) {
        try {
            auto msg = fmt::format(vfmt, read_args(L, flag, integers + 6)...);
            return zformat(L, lvl, tag, feature, msg);
        } catch (const exception& e) {
            luaL_error(L, "log format failed: %s!", e.what());
        }
        return 0;
    }

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

        lualog.set_function("print", [](lua_State* L) {
            log_level lvl = (log_level)lua_tointeger(L, 1);
            if (get_logger()->is_filter(lvl)) return 0;
            size_t flag = lua_tointeger(L, 2);
            sstring tag = lua_to_native<sstring>(L, 3);
            sstring feature = lua_to_native<sstring>(L, 4);
            vstring vfmt = lua_to_native<vstring>(L, 5);
            int arg_num = lua_gettop(L) - 5;
            switch (arg_num) {
            case 0: return zformat(L, lvl, tag, feature, string(vfmt.data(), vfmt.size()));
            case 1: return tformat(L, lvl, tag, feature, flag, vfmt, make_index_sequence<1>{});
            case 2: return tformat(L, lvl, tag, feature, flag, vfmt, make_index_sequence<2>{});
            case 3: return tformat(L, lvl, tag, feature, flag, vfmt, make_index_sequence<3>{});
            case 4: return tformat(L, lvl, tag, feature, flag, vfmt, make_index_sequence<4>{});
            case 5: return tformat(L, lvl, tag, feature, flag, vfmt, make_index_sequence<5>{});
            case 6: return tformat(L, lvl, tag, feature, flag, vfmt, make_index_sequence<6>{});
            case 7: return tformat(L, lvl, tag, feature, flag, vfmt, make_index_sequence<7>{});
            case 8: return tformat(L, lvl, tag, feature, flag, vfmt, make_index_sequence<8>{});
            default: luaL_error(L, "log format args is more than 8!"); break;
            }
            return 0;
        });
        
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
