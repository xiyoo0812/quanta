#include <string>
#include <vector>
#include "http.h"

inline void native_to_lua(lua_State* L, const httplib::Headers& v)
{
    lua_newtable(L);
    for (auto it : v)
    {
        lua_pushstring(L, it.second.c_str());
        lua_setfield(L, -2, it.first.c_str());
    }
}

EXPORT_CLASS_BEGIN(http_server)
EXPORT_LUA_FUNCTION(listen)
EXPORT_LUA_FUNCTION(update)
EXPORT_LUA_FUNCTION(error)
EXPORT_LUA_FUNCTION(logger)
EXPORT_LUA_FUNCTION(response)
EXPORT_LUA_FUNCTION(post)
EXPORT_LUA_FUNCTION(get)
EXPORT_CLASS_END()

const int WORK_COUNT_PER_FRAME = 20;

///////////////////////////////////////////////////////////////////////////////////
http_server::http_server(lua_State* L) :m_lvm(L), m_svr()
{
}

http_server::~http_server()
{
    m_svr.stop();
    m_lvm = nullptr;
}

int http_server::listen(lua_State* L)
{
    bool res = true;
    auto svr = &m_svr;
    const char* host = lua_tostring(L, 1);
    int port = lua_tointeger(L, 2);
    std::condition_variable cond_;
    std::thread([=, &res, &cond_]() {
        res = svr->listen(host, port);
    }).detach();
    std::mutex mutex_;
    std::unique_lock<std::mutex> lock(mutex_);
    cond_.wait_for(lock, std::chrono::seconds(1));
    lua_pushboolean(L, res);
    return 1;
}

void http_server::update()
{
    std::vector<std::function<void()>> fn_list;
    {
        std::unique_lock<std::mutex> lock(mutex_job);
        int count = WORK_COUNT_PER_FRAME;
        while (!jobs_.empty() && count-- > 0)
        {
            fn_list.push_back(jobs_.front());
            jobs_.pop_front();
        }
    }
    for (auto it : fn_list) it();
}

int http_server::logger(lua_State* L) 
{
    const char* method = lua_tostring(L, 1);
    m_svr.set_logger([=](const httplib::Request& req, const httplib::Response& res) {
        enqueue([=]() {
            lua_guard g(m_lvm);
            lua_call_object_function(m_lvm, nullptr, this, method, std::tie(), req.path, req.headers, req.body, res.status, res.body);
        });
    });
    return 0;
}

int http_server::error(lua_State* L)
{
    const char* method = lua_tostring(L, 1);
    m_svr.set_error_handler([=](const httplib::Request& req, httplib::Response& res) {
        enqueue([=]() {
            lua_guard g(m_lvm);
            lua_call_object_function(m_lvm, nullptr, this, method, std::tie(), req.path, req.headers, req.body, res.status, res.body);
        });
    });
    return 0;
}


int http_server::response(lua_State* L)
{
    uint64_t cond_ = lua_tointeger(L, 1);
    const char* resp_string = lua_tostring(L, 2);
    const char* content_type = lua_tostring(L, 3);
    std::unique_lock<std::mutex> lock(mutex_callback);
    auto iter = callbacks_.find(cond_);
    if (iter != callbacks_.end())
    {
        iter->second(resp_string, content_type);
    }
    return 0;
}

int http_server::post(lua_State* L)
{
    const char* pattarn = lua_tostring(L, 1);
    const char* method = lua_tostring(L, 2);
    m_svr.Post(pattarn, [=](const httplib::Request& req, httplib::Response& res) {
        std::condition_variable cond_;
        uint64_t addr = (uint64_t)&cond_;
        set_response_callback(addr, [&](const char* resp_string, const char* content_type) {
            res.set_content(resp_string, content_type);
            cond_.notify_one();
        });
        enqueue([&]() {
            lua_guard g(m_lvm);
            lua_call_object_function(m_lvm, nullptr, this, method, std::tie(), addr, req.path, req.body, req.headers);
        });
        std::mutex mutex_t;
        std::unique_lock<std::mutex> lock(mutex_t);
        cond_.wait_for(lock, std::chrono::seconds(5));
        clear_response_callback(addr);
    });
    lua_pushinteger(L, true);
    return 1;
}

int http_server::get(lua_State* L)
{
    const char* pattarn = lua_tostring(L, 1);
    const char* method = lua_tostring(L, 2);
    m_svr.Get(pattarn, [=](const httplib::Request& req, httplib::Response& res) {
        std::condition_variable cond_;
        uint64_t addr = (uint64_t)&cond_;
        set_response_callback(addr, [&](const char* resp_string, const char* content_type) {
            res.set_content(resp_string, content_type);
            cond_.notify_one();
        });
        enqueue([&]() {
            lua_guard g(m_lvm);
            lua_call_object_function(m_lvm, nullptr, this, method, std::tie(), addr, req.path, req.headers);
        });
        std::mutex mutex_t;
        std::unique_lock<std::mutex> lock(mutex_t);
        cond_.wait_for(lock, std::chrono::seconds(5));
        clear_response_callback(addr);
    });
    lua_pushinteger(L, true);
    return 1;
}
