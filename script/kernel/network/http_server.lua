--http_server.lua
import("driver/http.lua")
local ljson = require("luacjson")
ljson.encode_sparse_array(true)

local type          = type
local ssplit        = string_ex.split
local tunpack       = table.unpack
local json_encode   = ljson.encode
local log_info      = logger.info

local server        = http.server()
local thread_mgr    = quanta.thread_mgr

local HttpServer = class(http_addr)
function HttpServer:__init()
    --初始化
    self:setup(http_addr)
end

--初始化
function HttpServer:setup(http_addr, post_handler, get_handler)
    if post_handler then
        server.on_post = function(session, path, body, headers)
            thread_mgr:fork(function()
                local resp = post_handler(path, body, headers)
                self:response(session, resp)
            end)
        end
        server.post("/(.*)", "on_post")
    end
    if get_handler then
        server.on_get = function(session, path, headers)
            thread_mgr:fork(function()
                local resp = get_handler(path, headers)
                self:response(session, resp)
            end)
        end
        server.get("/(.*)", "on_get")
    end
    local ip, port = tunpack(ssplit(http_addr, ":"))
    if not server.listen(ip, port) then
        log_info("http now listen %s failed", http_addr)
        os.exit(1)
    end
    log_info("http now listen %s success!", http_addr)
end

function HttpServer:response(session, resp)
    if type(resp) == "table" then
        resp = json_encode(resp)
    end
    server.response(session, resp, "application/json")
end

return HttpServer
