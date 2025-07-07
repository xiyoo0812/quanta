#pragma once
#include <regex>
#include <filesystem>

#include "lua_buff.h"
#include "lua_time.h"
#include "lua_codec.h"
#include "lua_table.h"
#include "lua_class.h"

namespace luakit {
    inline thread_local luabuf lbuf;
    inline luabuf* get_buff() {
        return &lbuf;
    }

    inline codec_base* lua_codec() {
        luacodec* codec = new luacodec();
        codec->set_buff(&lbuf);
        return codec;
    }

    class kit_state;
    void luakit_extendlibs(kit_state* kit);

    class kit_state {
    public:
        kit_state() {
            m_L = luaL_newstate();
            luaL_openlibs(m_L);
            new_class<kit_state>();
            new_class<codec_base>();
            new_class<class_member>();
            new_class<function_wrapper>();
            new_class<slice>(
                "size", &slice::size,
                "recv", &slice::recv,
                "peek", &slice::check,
                "string", &slice::string
            );
            luakit_extendlibs(this);
            lua_checkstack(m_L, 1024);
            lua_table luakit = new_table("luakit");
            luakit.set_function("luacodec", lua_codec);
            luakit.set_function("encode", [&](lua_State* L) { return encode(L, &lbuf); });
            luakit.set_function("decode", [&](lua_State* L) { return decode(L, &lbuf); });
            luakit.set_function("unserialize", [&](lua_State* L) {  return unserialize(L); });
            luakit.set_function("serialize", [&](lua_State* L) { return serialize(L, &lbuf); });
        }
        kit_state(lua_State* L) : m_L(L) {}

        void __gc() {}

        void close() {
            if (m_L) {
                lua_close(m_L); 
                m_L = nullptr;
            }
        }

        template<typename T>
        void set(const char* name, T obj) {
            native_to_lua(m_L, obj);
            lua_setglobal(m_L, name);
        }

        template<typename T>
        T get(const char* name) {
            lua_guard g(m_L);
            lua_getglobal(m_L, name);
            return lua_to_native<T>(m_L, -1);
        }

        template<typename RET>
        bool get(const char* name, RET& ret) {
            lua_guard g(m_L);
            lua_getglobal(m_L, name);
            return lua_to_native(m_L, -1, ret);
        }

        template <typename F>
        void set_function(const char* function, F func) {
            lua_push_function(m_L, func);
            lua_setglobal(m_L, function);
        }

        bool get_function(const char* function) {
            get_global_function(m_L, function);
            return lua_isfunction(m_L, -1);
        }

        const char* get_path(const char* field) {
            lua_guard g(m_L);
            lua_getglobal(m_L, LUA_LOADLIBNAME);
            lua_getfield(m_L, -1, field);
            return lua_tostring(m_L, -1);
        }

        void set_path(const char* field, const char* path) {
            if (strcmp(field, "LUA_PATH") == 0) {
                set_lua_path("path", path, LUA_PATH_DEFAULT);
            } else {
                set_lua_path("cpath", path, LUA_CPATH_DEFAULT);
            }
        }

        void set_searchers(global_function fn) {
            lua_guard g(m_L);
            lua_getglobal(m_L, LUA_LOADLIBNAME);
            lua_getfield(m_L, -1, "searchers");
            lua_push_function(m_L, fn);
            lua_rawseti(m_L, -2, 2);
        }

        template <typename... ret_types, typename... arg_types>
        bool call(const char* function, error_fn efn, std::tuple<ret_types&...>&& rets, arg_types... args) {
            return call_global_function(m_L, function, efn, std::forward<std::tuple<ret_types&...>>(rets), std::forward<arg_types>(args)...);
        }

        bool call(const char* function, error_fn efn = nullptr) {
            return call_global_function(m_L, function, efn, std::tie());
        }

        bool call(error_fn efn = nullptr) {
            return lua_call_function(m_L, efn, std::tie());
        }

        template <typename... ret_types, typename... arg_types>
        bool table_call(const char* table, const char* function, error_fn efn, std::tuple<ret_types&...>&& rets, arg_types... args) {
            return call_table_function(m_L, table, function, efn, std::forward<std::tuple<ret_types&...>>(rets), std::forward<arg_types>(args)...);
        }

        template <typename... ret_types, typename... arg_types>
        bool table_call(const char* table, const char* function, error_fn efn, codec_base* codec, std::tuple<ret_types&...>&& rets, arg_types... args) {
            return call_table_function(m_L, table, function, efn, codec, std::forward<std::tuple<ret_types&...>>(rets), std::forward<arg_types>(args)...);
        }

        bool table_call(const char* table, const char* function, error_fn efn = nullptr) {
            return call_table_function(m_L, table, function, efn, std::tie());
        }

        template <typename T, typename... ret_types, typename... arg_types>
        bool object_call(T* obj, const char* function, error_fn efn, std::tuple<ret_types&...>&& rets, arg_types... args) {
            return call_object_function<T>(m_L, obj, function, efn, std::forward<std::tuple<ret_types&...>>(rets), std::forward<arg_types>(args)...);
        }

        template <typename T, typename... ret_types, typename... arg_types>
        bool object_call(T* obj, const char* function, error_fn efn, codec_base* codec, std::tuple<ret_types&...>&& rets, arg_types... args) {
            return call_object_function<T>(m_L, obj, function, efn, codec, std::forward<std::tuple<ret_types&...>>(rets), std::forward<arg_types>(args)...);
        }

        template <typename T>
        bool object_call(T* obj, const char* function, error_fn efn = nullptr) {
            return call_object_function<T>(function, obj, efn, std::tie());
        }

        bool run_file(const std::string& filename, error_fn efn = nullptr) {
            return run_file(filename.c_str(), efn);
        }

        bool run_file(const char* filename, error_fn efn = nullptr) {
            lua_guard g(m_L);
            if (luaL_loadfile(m_L, filename)) {
                if (efn) {
                    efn(lua_tostring(m_L, -1));
                }
                return false;
            }
            return lua_call_function(m_L, efn, 0, 0);
        }

        bool run_script(const std::string& script, error_fn efn= nullptr) {
            return run_script(script.c_str(), efn);
        }

        bool run_script(const char* script, error_fn efn= nullptr) {
            lua_guard g(m_L);
            if (luaL_loadstring(m_L, script)) {
                if (efn) {
                    efn(lua_tostring(m_L, -1));
                }
                return false;
            }
            return lua_call_function(m_L, efn, 0, 0);
        }

        lua_table new_table(const char* name = nullptr) {
            lua_guard g(m_L);
            lua_createtable(m_L, 0, 8);
            if (name) {
                lua_pushvalue(m_L, -1);
                lua_setglobal(m_L, name);
            }
            return lua_table(m_L);
        }

        template <typename... arg_types>
        lua_table new_table(const char* name, arg_types... args) {
            lua_table table = new_table(name);
            table.create_with(std::forward<arg_types>(args)...);
            return table;
        }

        template <typename... enum_value>
        lua_table new_enum(const char* name, enum_value... args) {
            lua_table table = new_table(name);
            table.create_with(std::forward<enum_value>(args)...);
            return table;
        }

        template<typename T, typename... arg_types>
        void new_class(arg_types... args) {
            lua_wrap_class<T>(m_L, std::forward<arg_types>(args)...);
        }

        template <typename T>
        int push(T v) {
            return native_to_lua(m_L, std::move(v));
        }

        template <typename T>
        reference new_reference(T v) {
            lua_guard g(m_L);
            native_to_lua(m_L, std::move(v));
            return reference(m_L);
        }

        lua_State* L() {
            return m_L;
        }

    protected:
        void set_lua_path(const char* fieldname, const char* path, const char* dft){
            std::string buffer;
            lua_table package = get<lua_table>(LUA_LOADLIBNAME);
            const char* dftmark = strstr(path, LUA_PATH_SEP LUA_PATH_SEP);
            if (dftmark != nullptr) {
                if (path < dftmark) {
                    buffer.append(path, dftmark - path);
                    buffer.append(LUA_PATH_SEP);
                }
                buffer.append(dft);
                size_t len = strlen(path);
                if (dftmark < path + len - 2) {
                    buffer.append(LUA_PATH_SEP);
                    buffer.append(dftmark + 2, (path + len - 2) - dftmark);
                }
            } else {
                buffer.append(path);
            }
#ifdef WIN32
            if (strstr(path, LUA_EXEC_DIR)) {
                auto cur_path = std::filesystem::current_path();
                auto temp = std::regex_replace(buffer, std::regex(LUA_EXEC_DIR), cur_path.string());
                package.set(fieldname, temp);
                return;
            }
#endif // WIN32
            package.set(fieldname, buffer);
        }

    protected:
        lua_State* m_L = nullptr;
    };

    inline void luakit_extendlibs(kit_state* kit) {
        auto lstring = kit->get<lua_table>("string");
        lstring.set_function("split", lua_string_split);
        lstring.set_function("title", lua_string_title);
        lstring.set_function("untitle", lua_string_untitle);
        lstring.set_function("ends_with", lua_string_ends_with);
        lstring.set_function("starts_with", lua_string_starts_with);
        auto ltable = kit->get<lua_table>("table");
        ltable.set_function("is_array", [](lua_State* L) { return is_lua_array(L, 1, true); });
    }
}
