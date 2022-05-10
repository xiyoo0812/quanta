# lcurl
一个封装curl的lua扩展库！

# 依赖
- [lua](https://github.com/xiyoo0812/lua.git)5.3以上
- 项目路径如下<br>
  |--proj <br>
  &emsp;|--lua <br>
  &emsp;|--lcurl

# 注意事项
- linux编译请先安装curl-devel。

# 用法
```lua
--本示例使用了quanta引擎
--https://github.com/xiyoo0812/quanta.git
--httpClient.lua
local lcurl     = require("lcurl")
local ljson     = require("lcjson")

local pairs     = pairs
local log_err   = logger.err
local tunpack   = table.unpack
local tinsert   = table.insert
local tconcat   = table.concat
local sformat   = string.format
local lquery    = lcurl.query
local luencode  = lcurl.url_encode
local lcrequest = lcurl.create_request
local jencode   = ljson.encode

local NetwkTime = enum("NetwkTime")
local thread_mgr= quanta.get("thread_mgr")

local HttpClient = singleton()
local prop = property(HttpClient)
prop:reader("contexts", {})

function HttpClient:__init()
    ljson.encode_sparse_array(true)
    --加入帧更新
    quanta.attach_frame(self)
end

function HttpClient:release()
    lcurl.destory()
end

function HttpClient:update()
    local curl_handle, result = lquery()
    while curl_handle do
        --查询请求结果
        local context = self.contexts[curl_handle];
        local request = context.request
        local session_id = context.session_id
        local content, err = request:get_respond()
        local info = request:get_info()
        if result == 0 then
            thread_mgr:response(session_id, true, info.code, content)
        else
            thread_mgr:response(session_id, false, info.code, err)
        end
        self.contexts[curl_handle] = nil
        request:close()
        curl_handle, result = lquery()
    end
    --清除超时请求
    local now_ms = quanta.now_ms
    for curl_handle, context in pairs(self.contexts) do
        if now_ms - context.time > NetwkTime.HTTP_CALL_TIMEOUT then
            context.request:close()
            self.contexts[curl_handle] = nil
        end
    end
end

function HttpClient:format_url(url, query)
    if next(query) then
        local fquery = {}
        for key, value in pairs(query) do
            tinsert(fquery, sformat("%s=%s", luencode(key), luencode(value)))
        end
        return sformat("%s?%s", url, tconcat(fquery, "&"))
    end
    return url
end

--格式化headers
function HttpClient:format_headers(request, headers)
    if next(headers) then
        local fmt_headers = {}
        for key, value in pairs(headers) do
            tinsert(fmt_headers, sformat("%s:%s", key, value))
        end
        request:set_headers(tunpack(fmt_headers))
    end
end

--构建请求
function HttpClient:build_request(url, session_id, headers, timeout)
    local request, curl_handle = lcrequest(url)
    if not request then
        log_err("[HttpClient][build_request] failed : %s", curl_handle)
        return
    end
    self.contexts[curl_handle] = {
        request = request,
        session_id = session_id,
        time = quanta.now_ms,
    }
    self:format_headers(request, headers or {})
    return request
end

--get接口
function HttpClient:call_get(url, querys, headers, timeout)
    local fmt_url = self:format_url(url, querys)
    local session_id = thread_mgr:build_session_id()
    local request = self:build_request(fmt_url, session_id, headers)
    if not request then
        log_err("[HttpClient][call_get] create request failed!")
        return false
    end
    local ok, err = request:call_get()
    if not ok then
        log_err("[HttpClient][call_get] curl call get failed: %s!", err)
        return false
    end
    return thread_mgr:yield(session_id, url, timeout or NetwkTime.HTTP_CALL_TIMEOUT)
end

--post接口
function HttpClient:call_post(url, post_datas, headers, timeout)
    if not headers then
        headers = {["Content-Type"] = "text/plain" }
    end
    print(type(post_datas))
    if type(post_datas) == "table" then
        post_datas = jencode(post_datas)
        headers["Content-Type"] = "application/json"
    end
    local session_id = thread_mgr:build_session_id()
    local request = self:build_request(url, session_id, headers)
    if not request then
        log_err("[HttpClient][call_post] create request failed!")
        return false
    end
    local ok, err = request:call_post(post_datas)
    if not ok then
        log_err("[HttpClient][call_post] curl call post failed: %s!", err)
        return false
    end
    return thread_mgr:yield(session_id, url, timeout or NetwkTime.HTTP_CALL_TIMEOUT)
end

--put接口
function HttpClient:call_put(url, put_datas, headers, timeout)
    if not headers then
        headers = {["Content-Type"] = "text/plain" }
    end
    if type(put_datas) == "table" then
        put_datas = jencode(put_datas)
        headers["Content-Type"] = "application/json"
    end
    local session_id = thread_mgr:build_session_id()
    local request = self:build_request(url, session_id, headers)
    if not request then
        log_err("[HttpClient][call_put] create request failed!")
        return false
    end
    local ok, err = request:call_put(put_datas)
    if not ok then
        log_err("[HttpClient][call_put] curl call put failed: %s!", err)
        return false
    end
    return thread_mgr:yield(session_id, url, timeout or NetwkTime.HTTP_CALL_TIMEOUT)
end

--del接口
function HttpClient:call_del(url, querys, headers, timeout)
    local fmt_url = self:format_url(url, querys)
    local session_id = thread_mgr:build_session_id()
    local request = self:build_request(fmt_url, session_id, headers)
    if not request then
        log_err("[HttpClient][call_del] create request failed!")
        return false
    end
    local ok, err = request:call_del()
    if not ok then
        log_err("[HttpClient][call_del] curl call del failed: %s!", err)
        return false
    end
    return thread_mgr:yield(session_id, url, timeout or NetwkTime.HTTP_CALL_TIMEOUT)
end

quanta.http_client = HttpClient()

return HttpClient

```
