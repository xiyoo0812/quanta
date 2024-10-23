#ifndef __SCHEDULER_H__
#define __SCHEDULER_H__
#include <condition_variable>

#include "worker.h"

using namespace std::chrono;

namespace lworker {

    class scheduler : public ischeduler
    {
    public:
        ~scheduler() {
            shutdown();
        }

        void setup(lua_State* L, vstring ns) {
            m_namespace = ns;
            m_lua = std::make_shared<kit_state>(L);
            lua_table quanta = m_lua->get<lua_table>(ns.data());
            m_platform = quanta.get<sstring>("platform");
            quanta.get("environs", m_environs);
            m_codec = luakit::get_codec();
        }

        std::shared_ptr<worker> find_worker(vstring name) {
            std::unique_lock<spin_mutex> lock(m_mutex);
            auto it = m_worker_map.find(name);
            if (it != m_worker_map.end()) {
                return it->second;
            }
            return nullptr;
        }

        bool startup(vstring name, environ_map& envs, vstring conf, kit_state* ks) {
            std::unique_lock<spin_mutex> lock(m_mutex);
            auto it = m_worker_map.find(name);
            if (it == m_worker_map.end()) {
                auto workor = std::make_shared<worker>(this, ks, name, m_namespace, m_platform);
                m_worker_map.insert(std::make_pair(name, workor));
                workor->startup(m_environs, envs, conf);
                return true;
            }
            return false;
        }

        uint8_t* encode(lua_State* L, size_t& data_len) {
            return m_codec->encode(L, 2, &data_len);
        }

        int broadcast(lua_State* L) {
            size_t data_len;
            uint8_t* data = m_codec->encode(L, 2, &data_len);
            if (data) {
                std::unique_lock<spin_mutex> lock(m_mutex);
                for (auto it : m_worker_map) {
                    it.second->call(L, data, data_len);
                }
            }
            return 0;
        }

        int call(lua_State* L, vstring name, uint8_t* data, size_t data_len) {
            if (data) {
                if (name == "master") {
                    lua_pushboolean(L, call(L, data, data_len));
                    return 1;
                }
                auto workor = find_worker(name);
                if (workor) {
                    lua_pushboolean(L, workor->call(L, data, data_len));
                    return 1;
                }
            }
            lua_pushboolean(L, false);
            return 1;
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
            if (clock_ms - m_last_tick > 1000) {
                m_last_tick = clock_ms;
                check_worker();
            }
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
                m_lua->table_call(ns, "on_scheduler", nullptr, m_codec, std::tie());
                if (m_codec->failed()) {
                    m_read_buf->clean();
                    break;
                }
                m_read_buf->pop_size(plen);
                if (luakit::steady_ms() - clock_ms > 100) break;
                slice = read_slice(m_read_buf, &plen);
            }
        }

        void check_worker() {
            std::unique_lock<spin_mutex> lock(m_mutex);
            for (auto& [name, worker] : m_worker_map) {
                if (!worker->running()) {
                    worker->stop();
                    m_worker_map.erase(name);
                    break;
                }
            }
        }

        void stop(vstring name) {
            std::unique_lock<spin_mutex> lock(m_mutex);
            auto it = m_worker_map.find(name);
            if (it != m_worker_map.end()) {
                it->second->stop();
                m_worker_map.erase(it);
            }
        }

        void shutdown() {
            std::unique_lock<spin_mutex> lock(m_mutex);
            for (auto it : m_worker_map) {
                it.second->stop();
            }
            m_worker_map.clear();
        }

    private:
        spin_mutex m_mutex;
        uint64_t m_last_tick = 0;
        environ_map m_environs = {};
        codec_base* m_codec = nullptr;
        sstring m_namespace, m_platform;
        std::shared_ptr<kit_state> m_lua = nullptr;
        std::shared_ptr<luabuf> m_read_buf = std::make_shared<luabuf>();
        std::shared_ptr<luabuf> m_write_buf = std::make_shared<luabuf>();
        std::map<sstring, std::shared_ptr<worker>, std::less<>> m_worker_map;
    };
}

#endif
