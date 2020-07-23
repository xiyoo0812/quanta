--web_mgr.lua
import("driver/http.lua")
local ljson         = require("luacjson")
local HttpServer    = import("kernel/network/http_server.lua")

local jdecode       = ljson.decode
local tunpack       = table.unpack
local sformat       = string.format
local env_get       = environ.get
local log_err       = logger.err
local log_debug     = logger.debug

local http          = quanta.http
local event_mgr     = quanta.event_mgr

local WebMgr = singleton()
local prop = property(WebMgr)
prop:accessor("url_host", "")
prop:accessor("http_server", nil)

function WebMgr:__init()
    ljson.encode_sparse_array(true)
    --创建HTTP服务器
    self.http_server = HttpServer()
    local function web_post(path, body, headers)
        return self:on_web_post(path, body, headers)
    end
    local function web_get(path, headers)
        return self:on_web_get(path, headers)
    end
    self.http_server:setup(env_get("QUANTA_WEBHTTP_ADDR"), web_post, web_get)
    --初始化网页后台地址
    self.url_host = env_get("QUANTA_WEBADMIN_HOST")
end

-- node请求服务
function WebMgr:forward_request(api_name, method, ...)
    local ok, code, res = http[method](http, sformat("%s/%s", self.url_host, api_name), ...)
    if not ok or code ~= 200 then
        return ok and code or 404
    end
    local body = jdecode(res)
    if body.code ~= 0 then
        return body.code, body.msg
    end
    return body.code, body.data
end

--http post 回调
function WebMgr:on_web_post(path, body, headers)
    log_debug("[WebMgr][on_web_post]: %s, %s, %s", path, body, headers)
    if path == "/gm" then
        local ok, res = tunpack(event_mgr:notify_listener("on_web_command", body, headers))
        if not ok then
            log_err("[WebMgr:on_web_post] on_web_command err: %s", res)
            return {code = 1, msg = res}
        end
        return res
    elseif path == "/message" then
        local ok, res = tunpack(event_mgr:notify_listener("on_web_message", body, headers))
        if not ok then
            log_err("[WebMgr:on_web_post] on_web_message err: %s", res)
            return {code = 1, msg = res}
        end
        return res
    else
        return {code = 1, msg = "path not exist!"}
    end
end

--http get 回调
function WebMgr:on_web_get(path, headers)
    log_debug("[WebMgr][on_web_get]: %s, %s", path, headers)
end

quanta.web_mgr = WebMgr()

return WebMgr
