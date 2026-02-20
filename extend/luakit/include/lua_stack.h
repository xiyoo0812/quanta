#pragma once

#include "lua_base.h"

namespace luakit {
    template <typename T> inline constexpr bool is_smart_ptr_v = false;
    template <typename T> inline constexpr bool is_smart_ptr_v<std::weak_ptr<T>> = true;
    template <typename T> inline constexpr bool is_smart_ptr_v<std::shared_ptr<T>> = true;
    template <typename T, typename D> inline constexpr bool is_smart_ptr_v<std::unique_ptr<T, D>> = true;

    template <typename T> inline constexpr bool is_string_v = false;
    template <typename C, typename T> inline constexpr bool is_string_v<std::basic_string_view<C, T>> = true;
    template <typename C, typename T, typename A> inline constexpr bool is_string_v<std::basic_string<C, T, A>> = true;

    template <typename T> inline constexpr bool is_span_v = false;
    template <typename T, size_t N> inline constexpr bool is_span_v<std::span<T, N>> = true;

    template <typename T> inline constexpr bool is_path_v = false;
    template <> inline constexpr bool is_path_v<std::filesystem::path> = true;

    template <typename T> using rm_cvref_t = std::remove_cvref_t<T>;
    template <typename T> concept std_keytype = requires { typename rm_cvref_t<T>::key_type; };
    template <typename T> concept std_mapped = requires { typename rm_cvref_t<T>::mapped_type; };

    template <typename T>
    concept std_container = !is_string_v<rm_cvref_t<T>> && !is_span_v<rm_cvref_t<T>> && requires(rm_cvref_t<T> t) {
        typename rm_cvref_t<T>::value_type; typename rm_cvref_t<T>::iterator; typename rm_cvref_t<T>::size_type;
        { std::begin(t) } -> std::same_as<typename rm_cvref_t<T>::iterator>;
        { std::end(t) } -> std::same_as<typename rm_cvref_t<T>::iterator>;
    };
    template <typename T> concept std_smart_ptr = is_smart_ptr_v<T>;
    template <typename T> concept std_fspath = is_path_v<rm_cvref_t<T>>;
    template <typename T> concept std_string = is_string_v<rm_cvref_t<T>>;
    template <typename T> concept std_map = std_container<T> && std_mapped<T>;
    template <typename T> concept std_set = std_container<T> && std_keytype<T> && !std_mapped<T>;
    template <typename T> concept std_sequence = std_container<T> && !std_keytype<T> && !std_mapped<T>;
    template <typename T> concept std_integer = std::integral<rm_cvref_t<T>> || std::is_enum_v<rm_cvref_t<T>>;
    template <typename T> concept std_pointer = std::is_pointer_v<rm_cvref_t<T>> || std::same_as<rm_cvref_t<T>, std::nullptr_t>;

    template <std_string T>
    T lua_to_native(lua_State* L, int i) {
        size_t len;
        cpchar str = lua_tolstring(L, i, &len);
        return str == nullptr ? "" : T(str, len);
    }

    template <std_string T>
    int native_to_lua(lua_State* L, T v) {
        lua_pushlstring(L, v.data(), v.size());
        return 1;
    }

    template <std::floating_point T>
    T lua_to_native(lua_State* L, int i) {
        return (T)lua_tonumber(L, i);
    }

    template <std::floating_point T>
    int native_to_lua(lua_State* L, T v) {
        lua_pushnumber(L, v);
        return 1;
    }

    template <std_integer T>
    T lua_to_native(lua_State* L, int i) {
        if constexpr (std::is_same_v<T, bool>) {
            return lua_toboolean(L, i);
        }
        return (T)lua_tointeger(L, i);
    }

    template <std_integer T>
    int native_to_lua(lua_State* L, T v) {
        if constexpr (std::is_same_v<T, bool>) {
            lua_pushboolean(L, v);
        } else {
            lua_pushinteger(L, (lua_Integer)v);
        }
        return 1;
    }

    template <typename T>
    T lua_to_object(lua_State* L, int idx);
    template <typename T>
    void lua_push_object(lua_State* L, T obj);
    
    template <std_pointer T>
    T lua_to_native(lua_State* L, int i) {
        using type = rm_cvref_t<std::remove_pointer_t<T>>;
        if constexpr (std::is_same_v<type, char>) {
            return (T)lua_tostring(L, i);
        }
        return lua_to_object<T>(L, i);
    }

    template <std_pointer T>
    int native_to_lua(lua_State* L, T v) {
        using type = rm_cvref_t<std::remove_pointer_t<T>>;
        if constexpr (std::is_same_v<type, char>) {
            lua_pushstring(L, v);
        } else {
            lua_push_object(L, v);
        }
        return 1;
    }

    template <std_smart_ptr T>
    int native_to_lua(lua_State* L, T v) {
        if (v == nullptr) {
            lua_pushnil(L);
        } else {
            lua_push_object(L, v.get());
        }
        return 1;
    }
    

    //std::array/std::list/std::deque/std::forward_list
    //std::set/std::multiset/std::unordered_set/std::unordered_multiset
    template <typename T> requires(std_sequence<T> || std_set<T>)
    int native_to_lua(lua_State* L, const T& v) {
        uint32_t index = 1;
        lua_createtable(L, 0, v.size());
        for (auto item : v) {
            native_to_lua(L, item);
            lua_seti(L, -2, index++);
        }
        return 1;
    }

    //std::vector/std::list/std::deque/std::forward_list
    template <std_sequence T>
    T lua_to_native(lua_State* L, int i) {
        T v;
        if (lua_istable(L, i)) {
            auto len = lua_rawlen(L, i);
            for (int idx = 1; idx <= len; ++idx) {
                lua_geti(L, i, idx);
                v.emplace_back(lua_to_native<typename T::value_type>(L, -1));
                lua_pop(L, 1);
            }
        }
        return v;
    }

    //std::set/std::multiset/std::unordered_set/std::unordered_multiset
    template <std_set T>
    T lua_to_native(lua_State* L, int i) {
        T v;
        if (lua_istable(L, i)) {
            i = lua_absindex(L, i);
            lua_pushnil(L);
            while (lua_next(L, i) != 0) {
                v.emplace(lua_to_native<typename T::value_type>(L, -1));
                lua_pop(L, 1);
            }
        }
        return v;
    }

    template <std_map T>
    int native_to_lua(lua_State* L, const T& vtm) {
        lua_createtable(L, 0, vtm.size());
        for (auto& [k, v] : vtm) {
            native_to_lua(L, k);
            native_to_lua(L, v);
            lua_settable(L, -3);
        }
        return 1;
    }

    //std::map/std::multimap
    template <std_map T>
    T lua_to_native(lua_State* L, int i) {
        T v;
        if (lua_istable(L, i)) {
            i = lua_absindex(L, i);
            lua_pushnil(L);
            while (lua_next(L, i) != 0) {
                v.emplace(lua_to_native<typename T::key_type>(L, -2), lua_to_native<typename T::mapped_type>(L, -1));
                lua_pop(L, 1);
            }
        }
        return v;
    }

    template <std_fspath T>
    int native_to_lua(lua_State* L, T v) {
        lua_pushlstring(L, reinterpret_cast<cpchar>(v.u8string().c_str()), v.u8string().size());
        return 1;
    }

    template <std_fspath T>
    T lua_to_native(lua_State* L, int i) {
        std::string_view fpath = lua_to_native<std::string_view>(L, i);
        #if defined(WIN32)
            try { return T(fpath, std::locale(".UTF8")); }
            catch (...) {}
            return T(fpath, std::locale(""));
        #else
            return T(fpath);
        #endif
    }

    template <typename T>
    void lua_push_object(lua_State* L, T obj) {
        if (obj == nullptr) {
            lua_pushnil(L);
            return;
        }
        lua_getfield(L, LUA_REGISTRYINDEX, "__objects__");
        if (lua_isnil(L, -1)) {
            lua_pop(L, 1);
            lua_createtable(L, 0, 128);
            lua_createtable(L, 0, 4);
            lua_pushstring(L, "v");
            lua_setfield(L, -2, "__mode");
            lua_setmetatable(L, -2);
            lua_pushvalue(L, -1);
            lua_setfield(L, LUA_REGISTRYINDEX, "__objects__");
        }

        // stack: __objects__
        size_t pkey = lua_get_object_key(obj);
        if (lua_geti(L, -1, pkey) != LUA_TTABLE) {
            lua_pop(L, 1);
            lua_createtable(L, 0, 4);
            lua_pushlightuserdata(L, obj);
            lua_setfield(L, -2, "__pointer__");
            // stack: __objects__, table
            luaL_getmetatable(L, lua_get_meta_name<T>());
            if (lua_isnil(L, -1)) {
                lua_pop(L, 3);
                lua_pushlightuserdata(L, obj);
                return;
            }
            // stack: __objects__, table, metatab
            lua_setmetatable(L, -2);
            lua_pushvalue(L, -1);
            // stack: __objects__, table, table
            lua_seti(L, -3, pkey);
        }
        // stack: __objects__, table
        lua_remove(L, -2);
    }

    template <typename T>
    T lua_to_object(lua_State* L, int idx) {
        if (lua_istable(L, idx)) {
            lua_getfield(L, idx, "__pointer__");
            T obj = (T)lua_touserdata(L, -1);
            lua_pop(L, 1);
            return obj;
        }
        if (lua_isuserdata(L, idx)) {
            return (T)lua_touserdata(L, idx);
        }
        return nullptr;
    }

    template<typename... arg_types>
    void native_to_lua_mutil(lua_State* L, arg_types&&... args) {
        int _[] = { 0, (native_to_lua(L, args), 0)... };
    }

    template<size_t... integers, typename... var_types>
    void lua_to_native_mutil(lua_State* L, std::tuple<var_types&...>& vars, std::index_sequence<integers...>&&) {
        int _[] = { 0, (std::get<integers>(vars) = lua_to_native<var_types>(L, (int)integers - (int)sizeof...(integers)), 0)... };
    }
}
