-- http_test.lua

local ltime         = timer.time
local log_debug     = logger.debug

local thread_mgr    = quanta.get("thread_mgr")

local http_client   = quanta.http_client()

local data = {aaa = 123}

if quanta.index == 1 then
    thread_mgr:fork(function()
        local ok, status, body, headers = http_client:call_get("https://yuanbao.tencent.com/download")
        log_debug("call_get : {}, {}, {}, {}", ok, status, headers, body)
    end)
elseif quanta.index == 2 then
    local on_post = function(path, body, params)
        log_debug("on_post: path: {}, params: {}, body: {}", path, params, body)
        return body
    end
    local on_get = function(path, body, params)
        log_debug("on_get: path: {}, params: {}, body: {}", path, params, body)
        return params
    end
    local on_put = function(path, body, params)
        log_debug("on_put: path: {}, params: {}, body: {}", path, params, body)
        return body
    end
    local on_del = function(path, body, params)
        log_debug("on_del: path: {}, params: {}", path, params)
        return params
    end
    local HttpServer = import("network/http_server.lua")
    local server = HttpServer("0.0.0.0:8888")
    server:register_get("*", on_get)
    server:register_post("*", on_post)
    server:register_put("*", on_put)
    server:register_del("*", on_del)
    quanta.server = server
elseif quanta.index == 3 then
    for i = 1, 1 do
        local tk1 = ltime()
        thread_mgr:fork(function()
            local tk2 = ltime()
            local args = {key=1, value=2}
            log_debug("node_status1 : {}, {}, {}", tk2 - tk1, tk2, tk1)
            local ok, status, res = http_client:call_post("http://127.0.0.1:8888/node_status1", data, nil, args)
            log_debug("node_status1 : {}, {}, {}, {}", ltime() - tk2, ok, status, res)
        end)
        thread_mgr:fork(function()
            local tk2 = ltime()
            local args = {key=2, value=2}
            log_debug("node_status2 : {}, {}, {}", tk2 - tk1, tk2, tk1)
            local ok, status, res = http_client:call_get("http://127.0.0.1:8888/node_status2", args, nil, data)
            log_debug("node_status2 : {}, {}, {}, {}", ltime() - tk2, ok, status, res)
        end)
        thread_mgr:fork(function()
            local tk2 = ltime()
            local args = {key=3, value=2}
            log_debug("node_status3 : {}, {}, {}", tk2 - tk1, tk2, tk1)
            local ok, status, res = http_client:call_put("http://127.0.0.1:8888/node_status3", data, nil, args)
            log_debug("node_status3 : {}, {}, {}, {}", ltime() - tk2, ok, status, res)
        end)
        thread_mgr:fork(function()
            local tk2 = ltime()
            local args = {key=4, value=2}
            log_debug("node_status4 : {}, {}, {}", tk2 - tk1, tk2, tk1)
            local ok, status, res = http_client:call_del("http://127.0.0.1:8888/node_status4", args)
            log_debug("node_status4 : {}, {}, {}, {}", ltime() - tk2, ok, status, res)
        end)
    end
end