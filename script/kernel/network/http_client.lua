--httpClient.lua
local webclient     = require "webclient"

local pairs         = pairs
local tunpack       = table.unpack
local tinsert       = table.insert
local tconcat       = table.concat
local sformat       = string.format

local thread_mgr    = quanta.get("thread_mgr")

local NetwkTime     = enum("NetwkTime")

local function args_format(client, args)
    local fargs = {}
    for key, value in pairs(args or {}) do
        tinsert(fargs, sformat("%s=%s", client:url_encoding(key), client:url_encoding(value)))
    end
    return tconcat(fargs, "&")
end

local function url_format(client, path, querys)
    local args = args_format(client, querys)
    if #args > 0 then
        path = sformat("%s?%s", path, args)
    end
    return path
end

local function header_format(headers)
    local new_headers = {}
    for key, value in pairs(headers or {}) do
        tinsert(new_headers, sformat("%s:%s", key, value))
    end
    return new_headers
end

local HttpClient = singleton()
local prop = property(HttpClient)
prop:reader("client", nil)
prop:reader("contexts", {})

function HttpClient:__init()
    --创建client对象
    self.client = webclient.create()
    --加入帧更新
    quanta.join(self)
end

function HttpClient:update()
    local client = self.client
    local finish_key, result = client:query()
    while finish_key do
        --查询请求结果
        local context = self.contexts[finish_key];
        local request = context.request
        local session_id = context.session_id
        local content, err = client:get_respond(request)
        local info = client:get_info(request)
        if result == 0 then
            thread_mgr:response(session_id, true, info.response_code, content)
        else
            thread_mgr:response(session_id, false, info.response_code, err)
        end
        client:remove_request(request)
        self.contexts[finish_key] = nil
        finish_key, result = client:query()
    end

    --清除超时请求
    local now_ms = quanta.now_ms
    for key, context in pairs(self.contexts) do
        if now_ms - context.time > NetwkTime.HTTP_CALL_TIMEOUT then
            client:remove_request(context.request)
            self.contexts[key] = nil
        end
    end
end

function HttpClient:request(url, get, post, headers, timeout)
    local client = self.client
    local real_url = url_format(client, url, get)
    if post and type(post) == "table" then
        post = args_format(client, post)
    end
    local to = timeout or NetwkTime.HTTP_CALL_TIMEOUT
    local request, key = client:request(real_url, post, to)
    if not request then
        return false, "request failed"
    end
    local fheaders = header_format(headers)
    if #fheaders > 0 then
        client:set_httpheader(request, tunpack(fheaders))
    end
    local session_id = thread_mgr:build_session_id()
    self.contexts[key] = {
        request = request,
        session_id = session_id,
        time = quanta.now_ms,
    }
    return thread_mgr:yield(session_id, url, to)
end

--get接口
function HttpClient:call_get(url, querys, headers, timeout)
    return self:request(url, querys, nil, headers, timeout)
end

--post接口
function HttpClient:call_post(url, querys, post_data, headers, timeout)
    return self:request(url, querys, post_data, headers or {["Content-Type"]="application/json"}, timeout)
end

quanta.http_client = HttpClient()

return HttpClient
