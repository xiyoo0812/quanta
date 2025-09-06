#pragma once

#include <mutex>
#include <format>
#include <atomic>
#include <string>
#include <cstdint>
#include <typeindex>
#include <stdexcept>
#include <functional>
#include <type_traits>
#include <string_view>
#include <unordered_map>

extern "C" {
    #include "lua.h"
    #include "lualib.h"
    #include "lauxlib.h"
}

namespace luakit {

    //错误函数
    using error_fn = std::function<void(std::string_view err)>;

    //升级cpp23后使用标准库接口
    template <std::integral T>
    constexpr T byteswap(T value) noexcept {
        auto* bytes = reinterpret_cast<unsigned char*>(&value);
        for (std::size_t i = 0; i < sizeof(T) / 2; ++i) {
            std::swap(bytes[i], bytes[sizeof(T) - 1 - i]);
        }
        return value;
    }

    template<typename T>
    const char* lua_get_meta_name() {
        using OT = std::remove_cv_t<std::remove_pointer_t<T>>;
        return std::type_index(typeid(OT)).name();
    }

    inline size_t lua_get_object_key(void* obj) {
        return (size_t)obj;
    }

    class lua_guard {
    public:
        lua_guard(lua_State* L) : m_L(L) { m_top = lua_gettop(L); }
        ~lua_guard() { lua_settop(m_L, m_top); }
        lua_guard(const lua_guard& other) = delete;
        lua_guard(lua_guard&& other) = delete;
        lua_guard& operator =(const lua_guard&) = delete;
    private:
        int m_top = 0;
        lua_State* m_L = nullptr;
    };

    inline bool is_lua_array(lua_State* L, int index, bool emy_as_arr = false) {
        if (lua_type(L, index) != LUA_TTABLE) return false;
        size_t raw_len = lua_rawlen(L, index);
        if (raw_len == 0 && !emy_as_arr) return false;
        index = lua_absindex(L, index);
        lua_guard g(L);
        lua_pushnil(L);
        size_t curlen = 0;
        while (lua_next(L, index) != 0) {
            if (!lua_isinteger(L, -2)) return false;
            size_t key = lua_tointeger(L, -2);
            if (key <= 0 || key > raw_len) return false;
            lua_pop(L, 1);
            curlen++;
        }
        return curlen == raw_len;
    }

    inline bool lua_string_starts_with(lua_State* L, std::string_view str, std::string_view with) {
        return str.starts_with(with);
    }

    inline bool lua_string_ends_with(lua_State* L, std::string_view str, std::string_view with) {
        return str.ends_with(with);
    }

    inline char* lua_string_title(char* str) {
        if (str && *str) *str = std::toupper(static_cast<unsigned char>(*str));
        return str;
    }

    inline char* lua_string_untitle(char* str) {
        if (str && *str) *str = std::tolower(static_cast<unsigned char>(*str));
        return str;
    }

    inline int lua_string_split(lua_State* L, std::string_view str, std::string_view delim) {
        size_t step = delim.size();
        if (step == 0) luaL_error(L, "delimiter cannot be empty");
        size_t cur = 0, len = 0;
        size_t pos = str.find(delim);
        bool pack = luaL_opt(L, lua_toboolean, 3, true);
        if (pack) lua_createtable(L, 8, 0);
        while (pos != std::string_view::npos) {
            lua_pushlstring(L, str.data() + cur, pos - cur);
            if (pack) lua_seti(L, -2, ++len);
            cur = pos + step;
            pos = str.find(delim, cur);
        }
        if (str.size() > cur) {
            lua_pushlstring(L, str.data() + cur, str.size() - cur);
            if (pack) lua_seti(L, -2, ++len);
        }
        return (pack) ? 1 : (int)len;
    }

    class lua_exception : public std::logic_error {
    public:
        template <class... Args>
        explicit lua_exception(const char* fmt, Args&&... args) : std::logic_error(format(fmt, std::forward<Args>(args)...)) {}

    protected:
        template <class... Args>
        std::string format(const char* fmt, Args&&... args) {
            int buf_size = std::snprintf(nullptr, 0, fmt, std::forward<Args>(args)...) + 1;
            if (buf_size < 0) return "unknown error!";
            std::unique_ptr<char[]> buf = std::make_unique<char[]>(buf_size);
            std::snprintf(buf.get(), buf_size, fmt, std::forward<Args>(args)...);
            return std::string(buf.get(), buf_size - 1);
        }
    };

    class spin_mutex {
    public:
        spin_mutex() = default;
        spin_mutex(const spin_mutex&) = delete;
        spin_mutex& operator = (const spin_mutex&) = delete;
        void lock() {
            for (;;) {
                if (!flag.test_and_set(std::memory_order_relaxed)) {
                    std::atomic_thread_fence(std::memory_order_acquire);
                    break;
                }
                #if defined(_M_X64)
                    _mm_pause();
                #elif defined(__x86_64__)
                    __builtin_ia32_pause();
                #elif defined(__aarch64__)
                    __builtin_arm_yield();
                #endif
            }
        }
        bool try_lock() {
            return !flag.test_and_set(std::memory_order_acquire);
        }
        void unlock() {
            flag.clear(std::memory_order_release);
        }
    private:
        std::atomic_flag flag = ATOMIC_FLAG_INIT;
    }; //spin_mutex

}
