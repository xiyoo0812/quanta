#ifndef __SCHEDULER_H__
#define __SCHEDULER_H__
#include <map>
#include <shared_mutex>

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
            m_environs = quanta.get<environ_map>("environs");
            m_codec.set_buff(&m_enc);
        }

        std::shared_ptr<worker> find_worker(vstring name) {
            std::shared_lock lock(m_mutex);
            if (auto it = m_worker_map.find(name); it != m_worker_map.end()) {
                return it->second;
            }
            return nullptr;
        }

        bool startup(vstring name, environ_map& envs, vstring conf) {
            std::unique_lock lock(m_mutex);
            if (auto it = m_worker_map.find(name); it == m_worker_map.end()) {
                auto workor = std::make_shared<worker>(this, name, m_namespace, m_platform);
                m_worker_map.insert(std::make_pair(name, workor));
                workor->startup(m_environs, envs, conf);
                return true;
            }
            return false;
        }

        uint8_t* encode(lua_State* L, size_t& data_len) {
            return m_codec.encode(L, 2, &data_len);
        }

        int broadcast(lua_State* L) {
            size_t data_len;
            uint8_t* data = m_codec.encode(L, 1, &data_len);
            if (data) {
                std::shared_lock lock(m_mutex);
                for (auto& [_, worker] : m_worker_map) {
                    worker->call(L, data, data_len);
                }
            }
            return 0;
        }

        int call(lua_State* L, vstring name, uint8_t* data, size_t data_len) {
            if (name == "master") {
                return call(L, data, data_len);
            }
            auto workor = find_worker(name);
            if (workor) {
                return workor->call(L, data, data_len);
            }
            lua_pushboolean(L, false);
            lua_pushstring(L, "worker not found!");
            return 2;
        }

        int call(lua_State* L, uint8_t* data, size_t data_len) {
            if (data_len > USHRT_MAX) {
                lua_pushboolean(L, false);
                lua_pushstring(L, "send data large than USHRT_MAX!");
                return 2;
            }
            if (m_mbsc.push(data, data_len)) {
                lua_pushboolean(L, true);
                return 1;
            }
            lua_pushboolean(L, false);
            lua_pushstring(L, "send buff full!");
            return 2;
        }

        void update(uint64_t clock_ms) {
            if (clock_ms - m_last_tick > 1000) {
                m_last_tick = clock_ms;
                check_worker();
            }
            size_t size = m_mbsc.size();
            if (size == 0) return;
            // peek all data
            m_dec.clean();
            auto data = m_dec.peek_space(size);
            m_mbsc.pop(data, size);
            m_dec.pop_space(size);
            // process all data
            slice* slice = read_slice(m_dec);
            auto ns = m_namespace.c_str();
            while (slice) {
                m_codec.set_slice(slice);
                m_lua->table_call(ns, "on_scheduler", nullptr, &m_codec, std::tie());
                slice = read_slice(m_dec);
                if (luakit::steady_ms() - clock_ms > 100) break;
            }
        }

        void check_worker() {
            std::unique_lock lock(m_mutex);
            for (auto& [name, worker] : m_worker_map) {
                if (!worker->running()) {
                    worker->stop();
                    m_worker_map.erase(name);
                    break;
                }
            }
        }

        void stop(vstring name) {
            std::unique_lock lock(m_mutex);
            if (auto it = m_worker_map.find(name); it != m_worker_map.end()) {
                it->second->stop();
                m_worker_map.erase(it);
            }
        }

        void shutdown() {
            std::unique_lock lock(m_mutex);
            for (auto it : m_worker_map) {
                it.second->stop();
            }
            m_worker_map.clear();
        }

    private:
        luabuf m_enc, m_dec;
        worker_codec m_codec;
        uint64_t m_last_tick = 0;
        environ_map m_environs = {};
        std::shared_mutex m_mutex;
        sstring m_namespace, m_platform;
        mpscbuff<WORKER_CAPACITY> m_mbsc;
        std::shared_ptr<kit_state> m_lua = nullptr;
        std::map<sstring, std::shared_ptr<worker>, std::less<>> m_worker_map;
    };
}

#endif
