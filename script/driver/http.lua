--http.lua
local lhttp = require("luahttp")

local pairs         = pairs
local tinsert       = table.insert
local tconcat       = table.concat
local sformat       = string.format
local log_err       = logger.err
local log_warn      = logger.warn
local log_debug     = logger.debug
local serialize     = logger.serialize

local thread_mgr    = quanta.thread_mgr

local NetwkTime     = enum("NetwkTime")

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

local http = {}

--创建client对象
local client = lhttp.client()
--设置回调
client.on_response = function(session_id, status, body)
    thread_mgr:response(session_id, true, status, body)
end
--加入帧更新
quanta.join(client)

--get接口
http.call_get = function(url, querys, headers)
    headers = header_format(headers)
    local full_url = url_format(url, querys)

    local session_id = thread_mgr:build_session_id()
    local ok, err = client.get(full_url, "", headers, session_id)
    if ok then
        return thread_mgr:yield(session_id, NetwkTime.RPC_CALL_TIMEOUT)
    else
        log_warn("[http.call_get] ok=%s,err=%s", ok, err)
        return ok, err
    end
end

--post接口
http.call_post = function(url, querys, post_data, headers)
    headers = header_format(headers)
    local full_url = url_format(url, querys)

    local session_id = thread_mgr:build_session_id()
    local ok, err = client.post(full_url, post_data, headers, session_id)
    if ok then
        return thread_mgr:yield(session_id, NetwkTime.RPC_CALL_TIMEOUT)
    else
        log_warn("[http.call_get] ok=%s,err=%s", ok, err)
        return ok, err
    end
end

http.server = function()
    local server = lhttp.server()
    server.on_logger = function(path, header, body, status, res)
        log_debug("[httpsvr][logger]: %s, %s, %s, %s, %s", path, serialize(header), body, status, res)
    end
    server.on_error = function(path, header, body, status, res)
        log_err("[httpsvr][error]: %s, %s, %s, %s, %s", path, serialize(header), body, status, res)
    end
    server.error("on_error")
    server.logger("on_logger")
    --添加到自动更新列表
    quanta.join(server)
    return server
end

quanta.http = http

return http
