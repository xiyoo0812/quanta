#pragma once

#include "lua.hpp"
#include "luna.h"
#include "httplib.h"
#include "utility.h"


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
    http_client(lua_State* lua_vm, int thread_count = 6, size_t max_pending_req = 2048);

    ~http_client();

    int get(lua_State* L);
    int put(lua_State* L);
    int post(lua_State* L);
    int del(lua_State* L);

    // tick函数
    void update();

    DECLARE_LUA_CLASS(http_client);
protected:
    // lua参数解析
    bool parse_lua_request(lua_State* L, std::string& url, std::string& param,
        httplib::Headers& headers, uint64_t& context_id, int& lua_ret, std::string& lua_err);

    // 执行请求：在工作线程运行
    void do_request(const std::string& url, const std::string& method, const std::string& param,
        const httplib::Headers& headers, uint64_t context_id);

    // 通知结果: 在主线程运行
    void do_response(int state, const std::string& body, uint64_t context_id);

private:
    lua_State*                       m_lua_state;
    std::thread::id                  m_main_tid;     // 主线程ID
    std::mutex                       m_mutex;
    std::list<std::function<void()>> m_responses;    // 响应列表 
    httplib::ThreadPool              m_requests;     // 请求列表
    size_t                           m_max_pending_req;  // 最大未执行完成的任务
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
