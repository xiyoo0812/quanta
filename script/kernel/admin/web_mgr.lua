--web_mgr.lua
import("kernel/network/http_client.lua")
local ljson         = require("lcjson")
local HttpServer    = import("kernel/network/http_server.lua")

local jdecode       = ljson.decode
local tunpack       = table.unpack
local sformat       = string.format
local env_get       = environ.get
local log_err       = logger.err
local log_debug     = logger.debug

local http_client   = quanta.get("http_client")

local WebMgr = singleton()
local prop = property(WebMgr)
prop:reader("url_host", "")
prop:reader("get_handlers", {})
prop:reader("post_handlers", {})
prop:reader("http_server", nil)

function WebMgr:__init()
    ljson.encode_sparse_array(true)
    --创建HTTP服务器
    self.http_server = HttpServer()
    local function web_post(path, body, headers)
        return self:on_web_post(path, body, headers)
    end
    local function web_get(path, querys, headers)
        return self:on_web_get(path, querys, headers)
    end
    self.http_server:setup(env_get("QUANTA_WEBHTTP_ADDR"), web_post, web_get)
    --初始化网页后台地址
    self.url_host = env_get("QUANTA_WEBADMIN_HOST")
end

--注册http回调
function WebMgr:register_post(path, handler, target)
    log_debug("[WebMgr][register_post] path: %s", path)
    self.post_handlers[path] = {target, handler}
end

--注册http回调
function WebMgr:register_get(path, handler, target)
    log_debug("[WebMgr][register_get] path: %s", path)
    self.get_handlers[path] = {target, handler}
end

-- node请求服务
function WebMgr:forward_request(api_name, method, ...)
    local ok, code, res = http_client[method](http_client, sformat("%s/runtime/%s", self.url_host, api_name), ...)
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
    local handler_info = self.post_handlers[path]
    if not handler_info then
        log_err("[WebMgr:on_web_post] path %s not exist", path)
        return {code = 1, msg = "path not exist!"}
    end
    local target, handler = tunpack(handler_info)
    local ok, res = pcall(target[handler], target, body, headers)
    if not ok then
        log_err("[WebMgr:on_web_post] exec path %s err: %s", path, res)
        return {code = 1, msg = res}
    end
    return res
end

--http get 回调
function WebMgr:on_web_get(path, querys, headers)
    log_debug("[WebMgr][on_web_get]: %s, %s", path, querys, headers)
    local handler_info = self.get_handlers[path]
    if not handler_info then
        log_err("[WebMgr:on_web_get] path %s not exist", path)
        return {code = 1, msg = "path not exist!"}
    end
    local target, handler = tunpack(handler_info)
    local ok, res = pcall(target[handler], target, querys, headers)
    if not ok then
        log_err("[WebMgr:on_web_get] exec path %s err: %s", path, res)
        return {code = 1, msg = res}
    end
    return res
end

quanta.web_mgr = WebMgr()

return WebMgr
