#ifndef __WORKER_H__
#define __WORKER_H__
#include <thread>

#include "lua_kit.h"
#include "fmt/core.h"

#ifdef WIN32
#define getpid _getpid
#else
#include <unistd.h>
#endif

using namespace luakit;

using sstring = std::string;
using vstring = std::string_view;
using environ_map = std::map<sstring, sstring>;

namespace lworker {

    static slice* read_slice(std::shared_ptr<luabuf> buff, size_t* pack_len) {
        uint8_t* plen = buff->peek_data(sizeof(uint32_t));
        if (plen) {
            uint32_t len = *(uint32_t*)plen;
            uint8_t* pdata = buff->peek_data(len);
            if (pdata) {
                *pack_len = sizeof(uint32_t) + len;
                return buff->get_slice(len, sizeof(uint32_t));
            }
        }
        return nullptr;
    }

    class worker;
    class ischeduler {
    public:
        virtual int broadcast(lua_State* L) = 0;
        virtual int call(lua_State* L, vstring name, uint8_t* data, size_t data_len) = 0;
    };

    class worker
    {
    public:
        worker(ischeduler* schedulor, kit_state* ks, vstring name, vstring ns, vstring plat)
            : m_schedulor(schedulor), m_name(name), m_namespace(ns), m_platform(plat) {
            m_lua = std::shared_ptr<kit_state>(ks);
        }

        ~worker() {
            m_lua->close();
        }

        const char* get_env(const char* key) {
            auto it = m_environs.find(key);
            if (it != m_environs.end()) return it->second.c_str();
            return nullptr;
        }

        void set_env(const char* key, const char* value, int over = 0) {
            if (over == 1 || m_environs.find(key) == m_environs.end()) {
                m_environs[key] = value;
            }
        }

        bool call(lua_State* L, uint8_t* data, size_t data_len) {
            std::unique_lock<spin_mutex> lock(m_mutex);
            uint8_t* target = m_write_buf->peek_space(data_len + sizeof(uint32_t));
            if (target) {
                m_write_buf->write<uint32_t>(data_len);
                m_write_buf->push_data(data, data_len);
                return true;
            }
            return false;
        }

        void update(uint64_t clock_ms) {
            if (m_read_buf->empty()) {
                if (m_write_buf->empty()) {
                    return;
                }
                std::unique_lock<spin_mutex> lock(m_mutex);
                m_read_buf.swap(m_write_buf);
            }
            size_t plen = 0;
            const char* ns = m_namespace.c_str();
            slice* slice = read_slice(m_read_buf, &plen);
            while (slice) {
                m_codec->set_slice(slice);
                m_lua->table_call(ns, "on_worker", nullptr, m_codec, std::tie());
                if (m_codec->failed()) {
                    m_read_buf->clean();
                    break;
                }
                m_read_buf->pop_size(plen);
                slice = read_slice(m_read_buf, &plen);
                if (luakit::steady_ms() - clock_ms > 100) break;
            }
        }

        void startup(environ_map& old_envs, environ_map& new_envs, vstring conf){
            if (!conf.empty()) {
                for (auto& [key, value] : new_envs) {
                    auto ekey = fmt::format("QUANTA_{}", key);
                    std::transform(ekey.begin(), ekey.end(), ekey.begin(), [](auto c) { return std::toupper(c); });
                    set_env(ekey.c_str(), value.c_str(), 1);
                }
                m_lua->set("platform", m_platform);
                m_lua->set_function("set_env", [&](const char* key, const char* value) { set_env(key, value, 1); });
                m_lua->set_function("set_path", [&](const char* field, const char* path) { m_lua->set_path(field, path); });
                m_lua->run_script(fmt::format("dofile('{}')", conf), [&](std::string_view err) {
                    printf("worker load conf %s failed, because: %s", conf.data(), err.data());
                });
            } else {
                m_environs = old_envs;
                for (auto& [key, value] : new_envs) {
                    auto ekey = fmt::format("QUANTA_{}", key);
                    std::transform(ekey.begin(), ekey.end(), ekey.begin(), [](auto c) { return std::toupper(c); });
                    set_env(ekey.c_str(), value.c_str(), 1);
                }
                if (auto it = old_envs.find("LUA_PATH"); it != old_envs.end()) {
                    m_lua->set_path(it->first.c_str(), it->second.c_str());
                }
            }
            std::thread(&worker::run, this).swap(m_thread);
        }

        void run(){
            m_codec = luakit::get_codec();
            auto quanta = m_lua->new_table(m_namespace.c_str());
            auto tid = std::this_thread::get_id();
            quanta.set("thread", m_name);
            quanta.set("pid", ::getpid());
            quanta.set("tid", *(uint32_t*)&tid);
            quanta.set("platform", m_platform);
            quanta.set_function("stop", [&]() { m_running = false; });
            quanta.set_function("update", [&](uint64_t clock_ms) { update(clock_ms); });
            quanta.set_function("getenv", [&](const char* key) { return get_env(key); });
            quanta.set_function("setenv", [&](const char* key, const char* value) { return set_env(key, value, 1); });
            quanta.set_function("call", [&](lua_State* L, vstring name) {
                size_t data_len;
                uint8_t* data = m_codec->encode(L, 2, &data_len);
                return m_schedulor->call(L, name, data, data_len);
            });
            auto ehandler = [&](vstring err) {
                m_running = false;
                printf("worker load failed, because: %s\n", err.data());
            };
            auto sandbox = get_env("QUANTA_SANDBOX");
            if (sandbox) {
                if (!m_lua->run_script(fmt::format("require '{}'", sandbox), ehandler)) return;
            }
            auto entry = get_env("QUANTA_ENTRY");
            if (!m_lua->run_script(fmt::format("require '{}'", entry), ehandler)) return;

            const char* ns = m_namespace.c_str();
            while (m_running) {
                if (m_stop) {
                    m_lua->table_call(ns, "stop");
                    m_running = false;
                }
                m_lua->table_call(ns, "run");
            }
        }

        void stop(){
            m_stop = true;
            if (m_thread.joinable()) {
                m_thread.join();
            }
        }

        bool running() {
            return m_running;
        }

    private:
        spin_mutex m_mutex;
        std::thread m_thread;
        bool m_stop = false;
        bool m_running = true;
        environ_map m_environs = {};
        codec_base* m_codec = nullptr;
        ischeduler* m_schedulor = nullptr;
        std::shared_ptr<kit_state> m_lua = nullptr;
        std::string m_name, m_namespace, m_platform;
        std::shared_ptr<luabuf> m_read_buf = std::make_shared<luabuf>();
        std::shared_ptr<luabuf> m_write_buf = std::make_shared<luabuf>();
    };
}

#endif
