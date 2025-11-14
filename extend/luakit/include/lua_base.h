#pragma once

#include <mutex>
#include <format>
#include <atomic>
#include <string>
#include <cstdint>
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
        return typeid(OT).name();
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

    class lua_exception : public std::logic_error {
    public:
        template <class... Args>
        explicit lua_exception(const char* fmt, Args&&... args) : std::logic_error(format(fmt, std::forward<Args>(args)...)) {}

    protected:
        template <class... Args>
        std::string format(const char* fmt, Args&&... args) {
            try {
                return std::vformat(fmt, std::make_format_args(args...));
            } catch (const std::format_error& e) {
                return "Format error: " + std::string(e.what());
            }
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
                #if defined(_M_X64) || defined(_M_IX86)
                    _mm_pause();
                #elif defined(__x86_64__) || defined(__i386__)
                    __builtin_ia32_pause();
                #elif defined(__aarch64__) || defined(__arm64__)
                    #if defined(__APPLE__)
                        __asm__ volatile("yield");
                    #else
                        __builtin_arm_yield();
                    #endif
                #else
                    std::this_thread::yield();
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
