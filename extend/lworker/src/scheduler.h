#ifndef __SCHEDULER_H__
#define __SCHEDULER_H__
#include <condition_variable>

#include "worker.h"

using namespace std::chrono;
using vstring   = std::string_view;

namespace lworker {

    class scheduler : public ischeduler
    {
    public:
        void setup(lua_State* L, vstring service, vstring sandbox) {
            m_service = service;
            m_sandbox = sandbox;
            m_lua = std::make_shared<kit_state>(L);
            m_codec = m_lua->create_codec();
        }

        std::shared_ptr<worker> find_worker(vstring name) {
            std::unique_lock<spin_mutex> lock(m_mutex);
            auto it = m_worker_map.find(name);
            if (it != m_worker_map.end()){
                return it->second;
            }
            return nullptr;
        }

        bool startup(vstring name, vstring entry, vstring incl) {
            std::unique_lock<spin_mutex> lock(m_mutex);
            auto it = m_worker_map.find(name);
            if (it == m_worker_map.end()){
                auto workor = std::make_shared<worker>(this, name, entry, incl, m_service, m_sandbox);
                m_worker_map.insert(std::make_pair(name, workor));
                workor->startup();
                return true;
            }
            return false;
        }

        int broadcast(lua_State* L) {
            std::unique_lock<spin_mutex> lock(m_mutex);
            for (auto it : m_worker_map) {
                it.second->call(L);
            }
            return 0;
        }

        int call(lua_State* L, vstring name) {
            if (name == "master") {
                lua_pushboolean(L, call(L));
                return 1;
            }
            auto workor = find_worker(name);
            if (workor) {
                lua_pushboolean(L, workor->call(L));
                return 1;
            }
            lua_pushboolean(L, false);
            return 1;
        }

        bool call(lua_State* L) {
            size_t data_len;
            std::unique_lock<spin_mutex> lock(m_mutex);
            uint8_t* data = m_codec->encode(L, 2, &data_len);
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
                m_lua->table_call(service, "on_scheduler", nullptr, m_codec, std::tie());
                if (m_codec->failed()){
                    m_read_buf->clean();
                    break;
                }
                m_read_buf->pop_size(plen);
                if (ltimer::steady_ms() - clock_ms > 100) break;
                slice = read_slice(m_read_buf, &plen);
            }
        }

        void destory(vstring name) {
            std::unique_lock<spin_mutex> lock(m_mutex);
            auto it = m_worker_map.find(name);
            if (it != m_worker_map.end()) {
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
        codec_base* m_codec = nullptr;
        std::string m_service, m_sandbox;
        std::shared_ptr<kit_state> m_lua = nullptr;
        std::shared_ptr<luabuf> m_read_buf = std::make_shared<luabuf>();
        std::shared_ptr<luabuf> m_write_buf = std::make_shared<luabuf>();
        std::map<std::string, std::shared_ptr<worker>, std::less<>> m_worker_map;
    };
}

#endif
