#ifndef __WORKER_H__
#define __WORKER_H__
#include <mutex>
#include <atomic>
#include <thread>

#include "lua_kit.h"
#include "ltimer.h"
#include "fmt/core.h"

using namespace luakit;

using vstring   = std::string_view;

const int SOCKET_PACKET_MAX = 1024 * 1024 * 16; //16m

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
        virtual int broadcast(lua_State* L) = 0;
        virtual int call(lua_State* L, vstring name) = 0;
        virtual void destory(vstring name) = 0;
    };

    class worker
    {
    public:
        worker(ischeduler* schedulor, vstring name, vstring entry, vstring incl, vstring service, vstring sandbox)
            : m_schedulor(schedulor), m_name(name), m_entry(entry), m_service(service), m_sandbox(sandbox), m_include(incl) { }

        ~worker() {
            m_running = false;
            if (m_thread.joinable()) {
                m_thread.join();
            }
            m_lua->close();
        }

        const char* get_env(const char* key) {
            return getenv(key);
        }

        bool call(lua_State* L) {
            size_t data_len;
            std::unique_lock<spin_mutex> lock(m_mutex);
            uint8_t* data = m_codec->encode(L, 2, &data_len);
            if (data == nullptr) {
                return false;
            }
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
            const char* service = m_service.c_str();
            slice* slice = read_slice(m_read_buf, &plen);
            while (slice) {
                m_codec->set_slice(slice);
                m_lua->table_call(service, "on_worker", nullptr, m_codec, std::tie());
                if (m_codec->failed()) {
                    m_read_buf->clean();
                    break;
                }
                m_read_buf->pop_size(plen);
                slice = read_slice(m_read_buf, &plen);
                if (ltimer::steady_ms() - clock_ms > 100) break;
            }
        }

        void startup(){
            std::thread(&worker::run, this).swap(m_thread);
        }

        void run(){
            m_codec = m_lua->create_codec();
            auto quanta = m_lua->new_table(m_service.c_str());
            quanta.set("title", m_name);
            quanta.set_function("stop", [&]() { m_running = false; });
            quanta.set_function("update", [&](uint64_t clock_ms) { update(clock_ms); });
            quanta.set_function("getenv", [&](const char* key) { return get_env(key); });
            quanta.set_function("call", [&](lua_State* L, vstring name) { return m_schedulor->call(L, name); });
            m_lua->run_script(fmt::format("require '{}'", m_sandbox), [&](vstring err) {
                printf("worker load %s failed, because: %s", m_sandbox.c_str(), err.data());
                m_schedulor->destory(m_name);
                return;
            });
            m_lua->run_script(fmt::format("require '{}'", m_entry), [&](vstring err) {
                printf("worker load %s failed, because: %s", m_entry.c_str(), err.data());
                m_schedulor->destory(m_name);
                return;
            });
            if (!m_include.empty()) {
                m_lua->run_script(fmt::format("require '{}'", m_include), [&](vstring err) {
                    printf("worker load includes %s failed, because: %s", m_include.c_str(), err.data());
                    m_schedulor->destory(m_name);
                    return;
                });
            }
            m_running = true;
            const char* service = m_service.c_str();
            while (m_running) {
                if (m_stop) break;
                m_lua->table_call(service, "run");
            }
            if (!m_stop){
                m_schedulor->destory(m_name);
            }
        }

        void stop(){
            m_stop = true;
        }

    private:
        spin_mutex m_mutex;
        std::thread m_thread;
        bool m_stop = false;
        bool m_running = false;
        codec_base* m_codec = nullptr;
        ischeduler* m_schedulor = nullptr;
        std::string m_name, m_entry, m_service, m_sandbox, m_include;
        std::shared_ptr<kit_state> m_lua = std::make_shared<kit_state>();
        std::shared_ptr<luabuf> m_read_buf = std::make_shared<luabuf>();
        std::shared_ptr<luabuf> m_write_buf = std::make_shared<luabuf>();
    };
}

#endif
