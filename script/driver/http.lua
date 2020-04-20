--http.lua
local lhttp = require("luahttp")

local pairs         = pairs
local tostring      = tostring
local tinsert       = table.insert
local tconcat       = table.concat
local sformat       = string.format
local log_info      = logger.info
local log_debug     = logger.debug
local serialize     = logger.serialize

local thread_mgr = quanta.thread_mgr

local HTTP_RPC_TIMEOUT  = 5000

local function header_format(header)
    local new_header = {}
    for key, value in pairs(header or {}) do
        new_header[tostring(key)] = tostring(value)
    end
    return new_header
end

local function args_format(args)
    local fargs = {}
    for key, value in pairs(args or {}) do
        tinsert(fargs, sformat("%s=%s", key, value))
    end
    return tconcat(fargs, "&")
end

local function url_format(path, querys)
    local args = args_format(querys)
    if #args > 0 then
        path = sformat("%s?%s", path, args)
    end
    return path
end

http = {}
http.args_format = args_format
http.client = function(host, port, timeout)
    local client = lhttp.client(host, port, timeout)
    client.on_call = function(session_id, status, body)
        thread_mgr:response(session_id, true, status, body)
    end
    client.call_get = function(path, querys, headers)
        local session_id = thread_mgr:build_session_id()
        client.get(url_format(path, querys), header_format(headers), session_id)
        return thread_mgr:yield(session_id, HTTP_RPC_TIMEOUT)
    end
    client.call_del = function(path, body, headers, contont_type)
        local session_id = thread_mgr:build_session_id()
        client.del(path, header_format(headers), body, contont_type or "application/json", session_id)
        return thread_mgr:yield(session_id, HTTP_RPC_TIMEOUT)
    end
    client.call_put = function(path, body, headers, contont_type)
        local session_id = thread_mgr:build_session_id()
        client.put(path, header_format(headers), body, contont_type or "application/json", session_id)
        return thread_mgr:yield(session_id, HTTP_RPC_TIMEOUT)
    end
    client.call_post = function(path, body, headers, contont_type)
        local session_id = thread_mgr:build_session_id()
        client.post(path, header_format(headers), body, contont_type or "application/json", session_id)
        return thread_mgr:yield(session_id, HTTP_RPC_TIMEOUT)
    end
    log_info("[HttpMgr][new_client] %s:%s success", host, port)
    --添加到自动更新列表
    quanta.join(client)
    return client
end

http.server = function()
    local server = lhttp.server()
    server.on_logger = function(path, header, body, status, res)
        log_debug("[httpsvr][logger]: %s, %s, %s, %s, %s", path, serialize(header), body, status, res)
    end
    server.on_error = function(path, header, body, status, res)
        log_debug("[httpsvr][error]: %s, %s, %s, %s, %s", path, serialize(header), body, status, res)
    end
    server.error("on_error")
    server.logger("on_logger")
    --添加到自动更新列表
    quanta.join(server)
    return server
end
