#ifndef __WORKER_H__
#define __WORKER_H__
#include <mutex>
#include <atomic>

#include "buffer.h"
#include "fmt/core.h"

using namespace lcodec;

namespace lworker {

    static slice* read_slice(var_buffer& buff, size_t* pack_len) {
        uint8_t* plen = buff.peek_data(sizeof(uint16_t));
        if (plen) {
            uint16_t len = *(uint16_t*)plen;
            uint8_t* pdata = buff.peek_data(len);
            if (pdata) {
                *pack_len = sizeof(uint16_t) + len;
                return buff.get_slice(len, sizeof(uint16_t));
            }
        }
        return nullptr;
    }

    class spin_mutex {
    public:
        spin_mutex() = default;
        spin_mutex(const spin_mutex&) = delete;
        spin_mutex& operator = (const spin_mutex&) = delete;
        void lock() {
            while(flag.test_and_set(std::memory_order_acquire));
        }
        void unlock() {
            flag.clear(std::memory_order_release);
        }
    private:
        std::atomic_flag flag = ATOMIC_FLAG_INIT;
    }; //spin_mutex

    class worker;
    class ischeduler {
    public:
        virtual void wakeup(slice* buf) = 0;
        virtual void callback(slice* buf) = 0;
        virtual void destory(std::string& name, std::shared_ptr<worker> workor) = 0;
    };

    class worker :public std::enable_shared_from_this<worker>
    {
    public:
        worker(ischeduler* schedulor, std::string& name, std::string& entry, std::string& service, std::string& sandbox)
            : m_schedulor(schedulor), m_name(name), m_entry(entry), m_service(service), m_sandbox(sandbox) { }

        ~worker() {
            m_running = false;
            if (m_thread.joinable()) {
                m_thread.join();
            }
        }

        bool call(slice* buf) {
            std::unique_lock<spin_mutex> lock(m_mutex);
            m_buff.write<uint16_t>(buf->size());
            m_buff.push_data(buf->head(), buf->size());
            return true;
        }

        const char* get_env(const char* key) {
            return getenv(key);
        }

        void update() {
            if (!m_buff.empty()) {
                std::unique_lock<spin_mutex> lock(m_mutex);
                while (true) {
                    size_t plen = 0;
                    slice* slice = read_slice(m_buff, &plen);
                    if (!slice) break;
                    m_lua.table_call(m_service.c_str(), "on_worker", nullptr, std::tie(), slice);
                    m_buff.pop_size(plen);
                }
            }
        }

        void startup(lua_State* L){
            auto quanta = m_lua.new_table(m_service.c_str());
            quanta.set_function("stop", [&]() { stop(); });
            quanta.set_function("update", [&]() { update(); });
            quanta.set_function("getenv", [&](const char* key) { return get_env(key); });
            quanta.set_function("wakeup", [&](slice* buf) { m_schedulor->wakeup(buf); });
            quanta.set_function("callback", [&](slice* buf) { m_schedulor->callback(buf); });
            m_lua.run_script(fmt::format("require '{}'", m_sandbox), [&](std::string err) {
                luaL_error(L, err.c_str());
                return;
            });
            m_lua.run_script(fmt::format("require '{}'", m_entry), [&](std::string err) {
                luaL_error(L, err.c_str());
                return;
            });
            std::thread(&worker::run, this).swap(m_thread);
            
        }

        void run(){
            m_running = true;
            const char* service = m_service.c_str();
            while (m_running) {
                m_lua.table_call(service, "run");
            }
            m_schedulor->destory(m_name, shared_from_this());
        }

        void stop(){
            m_running = false;
        }

    private:
        var_buffer m_buff;
        spin_mutex m_mutex;
        std::thread m_thread;
        std::string m_name, m_entry, m_service, m_sandbox;
        luakit::kit_state m_lua;
        ischeduler* m_schedulor;
        bool m_running = false;
    };
}

#endif
