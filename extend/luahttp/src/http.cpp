#include "stdafx.h"
#include <string>
#include <vector>
#include "http.h"
#include "utility.h"

EXPORT_CLASS_BEGIN(http_client)
EXPORT_LUA_FUNCTION(update)
EXPORT_LUA_FUNCTION(post)
EXPORT_LUA_FUNCTION(put)
EXPORT_LUA_FUNCTION(get)
EXPORT_LUA_FUNCTION(del)
EXPORT_CLASS_END()

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

http_client::http_client(lua_State* lua_vm, int thread_count, size_t max_pending_req) :
    m_lua_state(lua_vm),
    m_requests(thread_count),
    m_max_pending_req(max_pending_req)
{

}

http_client::~http_client()
{
    m_requests.shutdown();
}

int http_client::get(lua_State* L)
{
    if (m_requests.task_count() >= m_max_pending_req)
    {
        lua_pushboolean(L, false);
        lua_pushstring(L, "too match pending task");
        return 2;
    }

    std::string url; 
    std::string param;
    httplib::Headers headers;
    uint64_t context_id = 0; 
    int lua_ret = 0; 
    std::string lua_err;

    if (!parse_lua_request(L, url, param, headers, context_id, lua_ret, lua_err))
    {
        lua_pushboolean(L, false);
        lua_pushstring(L, lua_err.c_str());
        return 2;
    }

    m_requests.enqueue([=](void)->void {
        this->do_request(url, "GET", param, headers, context_id);
    });

    lua_pushinteger(L, true);
    return 1;
}

int http_client::post(lua_State* L)
{
    if (m_requests.task_count() >= m_max_pending_req)
    {
        lua_pushinteger(L, false);
        lua_pushstring(L, "too match pending task");
        return 2;
    }

    std::string url;
    std::string param;
    httplib::Headers headers;
    uint64_t context_id = 0;
    int lua_ret = 0;
    std::string lua_err;

    if (!parse_lua_request(L, url, param, headers, context_id, lua_ret, lua_err))
    {
        lua_pushboolean(L, false);
        lua_pushstring(L, lua_err.c_str());
        return 2;
    }

    m_requests.enqueue([=](void)->void {
        this->do_request(url, "POST", param, headers, context_id);
    });

    lua_pushinteger(L, true);
    return 1;
}

int http_client::put(lua_State* L)
{
    lua_pushboolean(L, false);
    lua_pushstring(L, "not support");
    return 2;
}

int http_client::del(lua_State* L)
{
    lua_pushboolean(L, false);
    lua_pushstring(L, "not support");
    return 2;
}

void http_client::update()
{
    std::lock_guard<std::mutex> lock(m_mutex);
    if (m_responses.size() <= 0)
        return;

    auto job_cb = m_responses.back();
    job_cb();
    m_responses.pop_back();
}

bool http_client::parse_lua_request(lua_State* L, std::string& url, std::string& param,
    httplib::Headers& headers, uint64_t& context_id, int& lua_ret, std::string& lua_err)
{
    lua_guard g(L);
    // 参数获取： url param headers context_id
    int top = lua_gettop(L);
    if ((4 != top) || !lua_isstring(L, 1) || !lua_isstring(L, 2) || !lua_istable(L, 3) || !lua_isinteger(L, 4))
    {
        lua_ret = -1;
        lua_err = "need 4 parameter: url{string},param{string},headers{table},context_id{number}";
        return false;
    }

    url   = lua_tostring(L, 1);
    param = lua_tostring(L, 2);

    lua_pushnil(L);
    while (lua_next(L, 3))
    {
        lua_pushvalue(L, -2);
        const char* key = lua_tostring(L, -1);
        const char* value = lua_tostring(L, -2);
        headers.insert(std::make_pair(key, value));
        lua_pop(L, 2);
    }
    context_id = lua_tointeger(L, 4);
    return true;
}

void http_client::do_request(const std::string& url, const std::string& method, const std::string& param,
    const httplib::Headers& headers, uint64_t context_id)
{
    std::shared_ptr<httplib::Response> res_ptr;
    int ret = http_request(url, method, param, headers, 3, res_ptr);
    int status = 404;
    std::string body;
    if (0 == ret)
    {
        status = res_ptr->status;
        body = res_ptr->body;
    }
    std::unique_lock<std::mutex> lock(m_mutex);
    m_responses.push_back([=](void)->void {
        do_response(status, body, context_id);
    });
}

void http_client::do_response(int status, const std::string& body, uint64_t context_id)
{
    lua_guard g(m_lua_state);
    lua_call_object_function(m_lua_state, nullptr, this, "on_response", std::tie(), context_id, status, body);
}

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
