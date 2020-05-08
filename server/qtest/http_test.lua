-- http_test.lua
local ljson = require("luacjson")
local http  = import("driver/http.lua")
ljson.encode_sparse_array(true)

local json_encode   = ljson.encode
local serialize     = logger.serialize

local thread_mgr    = quanta.thread_mgr

local HttpTest = singleton()
function HttpTest:__init()
    self:setup()
end

function HttpTest:setup()
    --测试代码
    local data = {aaa = 123}
    if quanta.index == 1 then
        local on_post = function(path, body, headers)
            print("on_post:", path, body, headers)
            return data
        end
        local on_get = function(path, headers)
            print("on_get:", path, serialize(headers))
            return data
        end
        local HttpServer = import("kernel/network/http_server.lua")
        quanta.server = HttpServer("0.0.0.0:8888", on_post, on_get)
    elseif quanta.index == 2 then
        thread_mgr:fork(function()
            local ok, status, res = http.call_get("http://127.0.0.1:8888/test", json_encode(data))
            --local ok, status, res = client.call_post("http://127.0.0.1:8888/test", data, json_encode(data))
            print(ok, status, res)
        end)
    end
end

-- export
quanta.http_test = HttpTest()

return HttpTest
