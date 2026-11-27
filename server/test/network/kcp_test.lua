-- kcp_test.lua

require("luakcp")

local log_info      = logger.info

local thread_mgr    = quanta.get("thread_mgr")
local protobuf_mgr  = quanta.get("protobuf_mgr")

local PORT          = 28282
local ROUNDS        = 5

local TestCase      = import("test/case.lua")
local KcpServer     = import("network/kcp_server.lua")
local KcpClient     = import("network/kcp_client.lua")

local KcpTest       = class(TestCase)

--心跳请求处理: 必须在 register 之前定义(listen_message 会检查方法是否存在)
function KcpTest:on_heartbeat_req(message, body, response, session)
    response.time = quanta.now_ms
    response.serial = body.serial + 1
end

function KcpTest:run()
    --服务端: 注册心跳处理(响应 serial+1)
    local server = KcpServer()
    protobuf_mgr:register(self, "NID_HEARTBEAT_REQ", "on_heartbeat_req")
    local sok = server:listen("127.0.0.1", PORT)
    self:report("kcp server listen", sok ~= false, sok, true)

    --客户端: fork 协程内 connect + 串行 call
    local results = {}
    local client = nil
    thread_mgr:fork(function()
        client = KcpClient("127.0.0.1", PORT)
        local cok = client:connect()
        if cok ~= true then return end
        for i = 1, ROUNDS do
            local ok, res = client:call("NID_HEARTBEAT_REQ", { serial = i, time = quanta.now_ms })
            logger.dump("[kcp] round {}: ok={}, serial={}, time={}", i, ok, res and res.serial, res and res.time)
            results[i] = { ok = ok, res = res }
        end
    end)

    for _ = 1, 50 do
        if #results >= ROUNDS then break end
        thread_mgr:sleep(100)
    end

    self:report("kcp rounds count", #results == ROUNDS, #results, ROUNDS)
    local all_ok = true
    for i = 1, ROUNDS do
        local r = results[i]
        if not r or r.ok ~= true or not r.res or r.res.serial ~= i + 1 then
            all_ok = false
        end
    end
    self:report("kcp all rounds matched", all_ok, all_ok, true)

    --关闭连接, 结束 case
    if client then client:close() end
    log_info("[kcp] rounds={}, closed", #results)
end

return KcpTest
