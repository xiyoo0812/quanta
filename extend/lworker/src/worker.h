#ifndef __WORKER_H__
#define __WORKER_H__
#include <thread>

#include "lua_kit.h"

#ifdef WIN32
#define getpid _getpid
#else
#include <unistd.h>
#endif

using namespace luakit;

using environ_map = std::unordered_map<sstring, sstring>;

namespace lworker {

    const size_t WORKER_CAPACITY = 1024 * 1024 * 8;

    class worker_codec : public codec_base {
    public:
        virtual uint8_t* encode(lua_State* L, int index, size_t* len) {
            m_buf->clean();
            auto base = m_buf->hold_place(sizeof(uint16_t));
            int n = lua_gettop(L) - index + 1;
            encode_slice(L, m_buf, index, n);
            auto date_len = m_buf->size();
            m_buf->copy(base, (uint8_t*)&date_len, sizeof(uint16_t));
            return m_buf->data(len);
        }
    };

    static slice* read_slice(luabuf& buff) {
        uint16_t* plen = (uint16_t*)buff.peek_data(sizeof(uint16_t));
        if (plen) {
            buff.pop_size(sizeof(uint16_t));
            uint16_t len = *plen - sizeof(uint16_t);
            uint8_t* pdata = buff.peek_data(len);
            if (pdata) {
                auto slice = buff.get_slice(len);
                buff.pop_size(len);
                return slice;
            }
        }
        return nullptr;
    }

    class ischeduler {
    public:
        virtual int broadcast(lua_State* L) = 0;
        virtual int call(lua_State* L, vstring name, uint8_t* data, size_t data_len) = 0;
    };

    class worker
    {
    public:
        worker(ischeduler* schedulor, vstring name, vstring ns, vstring plat)
            : m_schedulor(schedulor), m_name(name), m_namespace(ns), m_platform(plat) {
        }

        ~worker() {
            m_lua.close();
        }

        cpchar get_env(cpchar key) {
            if (auto it = m_environs.find(key); it != m_environs.end()) return it->second.c_str();
            return nullptr;
        }

        void set_env(cpchar key, cpchar value, int over = 0) {
            if (over == 1 || !m_environs.contains(key)) {
                m_environs[key] = value;
            }
        }

        void add_path(cpchar field, cpchar path) {
            auto handle = m_environs.extract(field);
            if (handle.empty()) {
                m_environs[field] = path;
                m_lua.set_path(field, path);
                return;
            }
            auto& epath = handle.mapped();
            epath.append(path);
            m_environs.insert(std::move(handle));
            m_lua.set_path(field, epath.c_str());
        }

        int call(lua_State* L, uint8_t* data, size_t data_len) {
            if (data_len > USHRT_MAX) {
                lua_pushboolean(L, false);
                lua_pushstring(L, "send data large than USHRT_MAX!");
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
                m_lua.table_call(ns, "on_worker", nullptr, &m_codec, std::tie());
                slice = read_slice(m_dec);
                if (luakit::steady_ms() - clock_ms > 100) break;
            }
        }

        void startup(environ_map& old_envs, environ_map& new_envs, vstring conf){
            if (!conf.empty()) {
                for (auto& [key, value] : new_envs) {
                    auto ekey = std::format("QUANTA_{}", key);
                    std::transform(ekey.begin(), ekey.end(), ekey.begin(), [](auto c) { return std::toupper(c); });
                    set_env(ekey.c_str(), value.c_str(), 1);
                }
                m_lua.set("platform", m_platform);
                m_lua.set_function("set_env", [&](cpchar key, cpchar value) { set_env(key, value, 1); });
                m_lua.set_function("add_path", [&](cpchar field, cpchar path) { add_path(field, path); });
                m_lua.set_function("set_path", [&](cpchar field, cpchar path) { m_lua.set_path(field, path); });
                m_lua.run_script(std::format("dofile('{}')", conf), [&](std::string_view err) {
                    printf("worker load conf %s failed, because: %s", conf.data(), err.data());
                });
            } else {
                m_environs = old_envs;
                for (auto& [key, value] : new_envs) {
                    auto ekey = std::format("QUANTA_{}", key);
                    std::transform(ekey.begin(), ekey.end(), ekey.begin(), [](auto c) { return std::toupper(c); });
                    set_env(ekey.c_str(), value.c_str(), 1);
                }
                if (auto it = old_envs.find("LUA_PATH"); it != old_envs.end()) {
                    m_lua.set_path(it->first.c_str(), it->second.c_str());
                }
            }
            m_thread = std::jthread(std::bind(&worker::run, this, std::placeholders::_1));
        }

        void run(std::stop_token stoken){
            LOG_INIT(m_lua.L());
            m_codec.set_buff(&m_enc);
            auto quanta = m_lua.new_table(m_namespace.c_str());
            auto tid = std::this_thread::get_id();
            quanta.set("thread", m_name);
            quanta.set("pid", ::getpid());
            quanta.set("tid", m_thread.native_handle());
            quanta.set("platform", m_platform);
            quanta.set_function("stop", [&]() { m_running = false; });
            quanta.set_function("update", [&](uint64_t clock_ms) { update(clock_ms); });
            quanta.set_function("getenv", [&](cpchar key) { return get_env(key); });
            quanta.set_function("setenv", [&](cpchar key, cpchar value) { return set_env(key, value, 1); });
            quanta.set_function("call", [&](lua_State* L, vstring name) {
                size_t data_len;
                uint8_t* data = m_codec.encode(L, 2, &data_len);
                return m_schedulor->call(L, name, data, data_len);
            });
            quanta.set_function("broadcast", [&](lua_State* L) {
                return m_schedulor->broadcast(L);
            });
            auto ehandler = [&](vstring err) {
                m_running = false;
                printf("worker load failed, because: %s\n", err.data());
            };
            auto sandbox = get_env("QUANTA_SANDBOX");
            if (sandbox) {
                if (!m_lua.run_script(std::format("require '{}'", sandbox), ehandler)) return;
            }
            auto entry = get_env("QUANTA_ENTRY");
            if (!m_lua.run_script(std::format("require '{}'", entry), ehandler)) return;

            cpchar ns = m_namespace.c_str();
            while (m_running) {
                if (stoken.stop_requested()) {
                    m_lua.table_call(ns, "stop");
                    m_running = false;
                }
                m_lua.table_call(ns, "run");
            }
        }

        void stop(){
            m_thread.request_stop();
            m_thread.join();
        }

        bool running() {
            return m_running;
        }

    private:
        kit_state m_lua;
        luabuf m_enc, m_dec;
        worker_codec m_codec;
        environ_map m_environs = {};
        ischeduler* m_schedulor = nullptr;
        mpscbuff<WORKER_CAPACITY> m_mbsc;
        sstring m_name, m_namespace, m_platform;
        std::jthread m_thread;
        bool m_running = true;
    };
}

#endif
