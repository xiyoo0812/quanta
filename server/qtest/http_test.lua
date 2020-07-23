-- http_test.lua
import("driver/http.lua")
local ljson = require("luacjson")
ljson.encode_sparse_array(true)

local http          = quanta.http
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
            local post_data = json_encode({title = "test", text = "http test"})
        --    local ROBOT_URL = "https://open.feishu.cn/open-apis/bot/hook/56b34b9e1c0b4fc0acadef8ebc3894ad"
            local ROBOT_URL = "https://open.feishu.cn/open-apis/bot/hook/56b34b9e1c0b4fc0acadef8ebc3894ad"
            local ok, status, res = http:call_post(ROBOT_URL, {}, post_data)
            logger.info("feishu test : %s, %s, %s", ok, status, res)
        end)
        for i = 1, 1 do
            thread_mgr:fork(function()
                local tk = quanta.get_time_ms()
                local ok, status, res = http:call_post("http://10.100.0.19:8080/node_status", {}, json_encode(data))
                local now = quanta.get_time_ms()
                logger.info("node_status : %s, %s, %s, %s", now - tk, ok, status, res)
            end)
        end
    end
end

-- export
quanta.http_test = HttpTest()

return HttpTest
