#pragma once

#include "lua.hpp"
#include "luna.h"
#include "httplib.h"

class http_server
{
public:
    http_server(lua_State* L);
    ~http_server();

    void update();

    int listen(lua_State* L);

    int post(lua_State* L);

    int get(lua_State* L);

    int response(lua_State* L);

    int logger(lua_State* L);

    int error(lua_State* L);

    DECLARE_LUA_CLASS(http_server);

protected:
    inline void enqueue(std::function<void()> fn)
    {
        std::unique_lock<std::mutex> lock(mutex_job);
        jobs_.push_back(fn);
    }

    inline void set_response_callback(uint64_t cond, std::function<void(const char*, const char*)> fn)
    {
        std::unique_lock<std::mutex> lock(mutex_callback);
        callbacks_.insert(std::make_pair(cond, fn));
    }
 
    inline void clear_response_callback(uint64_t cond)
    {
        std::unique_lock<std::mutex> lock(mutex_callback);
        callbacks_.erase(cond);
    }
private:
    httplib::Server m_svr;
    lua_State* m_lvm = nullptr;

    std::mutex mutex_job;
    std::mutex mutex_callback;
    std::list<std::function<void()>> jobs_;
    std::map<uint64_t, std::function<void(const char*, const char*)>> callbacks_;
};
