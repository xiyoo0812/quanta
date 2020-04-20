#pragma once

#include "lua.hpp"
#include "luna.h"
#include "httplib.h"


inline void native_to_lua(lua_State* L, const httplib::Headers& v)
{
    lua_newtable(L);
    for (auto it : v)
    {
        lua_pushstring(L, it.second.c_str());
        lua_setfield(L, -2, it.first.c_str());
    }
}

class http_client
{
public:
    http_client(lua_State* L, const char *host, int port = 80, time_t timeout_sec = 10);
    ~http_client();

    void update();

    int put(lua_State* L);

	int post(lua_State* L);

    int get(lua_State* L);
    
    int del(lua_State* L);

    int follow_location(lua_State* L);

	DECLARE_LUA_CLASS(http_client);

protected:
    inline void enqueue(std::function<void()> fn)
    {
        std::unique_lock<std::mutex> lock(mutex_job);
        jobs_.push_back(fn);
    }

private:
    httplib::Client m_cli;
    httplib::ThreadPool m_threads;
    lua_State* m_lvm = nullptr;
    std::mutex mutex_job;
    std::list<std::function<void()>> jobs_;
};

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
