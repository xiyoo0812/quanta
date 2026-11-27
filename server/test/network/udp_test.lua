-- udp_test.lua
local log_info      = logger.info
local sformat       = string.format

local thread_mgr    = quanta.get("thread_mgr")

local PORT_SVR      = 28600
local PORT_CLI      = 28601
local ROUNDS        = 5

local TestCase      = import("test/case.lua")
local UdpTest       = class(TestCase)

function UdpTest:run()
    local server = luabus.udp(true)
    local sok, serr = server.bind("127.0.0.1", PORT_SVR)
    self:report("udp server bind", sok == true, serr, "ok")
    local client = luabus.udp(true)
    local cok, cerr = client.bind("127.0.0.1", PORT_CLI)
    self:report("udp client bind", cok == true, cerr, "ok")
    if not sok or not cok then return end

    local server_recvs = {}
    local client_recvs = {}

    --server 协程: 循环收 ROUNDS 次并逐条回复
    thread_mgr:fork(function()
        for i = 1, ROUNDS do
            for _ = 1, 50 do
                local ok, buf, ip, port = server.recv()
                if ok then
                    server_recvs[i] = buf
                    local reply = sformat("pong-%d", i)
                    server.send(reply, #reply, ip, port)
                    break
                end
                thread_mgr:sleep(20)
            end
        end
    end)

    --client 协程: 串行发 ROUNDS 次, 每次等回复
    thread_mgr:fork(function()
        for i = 1, ROUNDS do
            local data = sformat("ping-%d", i)
            client.send(data, #data, "127.0.0.1", PORT_SVR)
            for _ = 1, 50 do
                local ok, buf = client.recv()
                if ok then
                    client_recvs[i] = buf
                    break
                end
                thread_mgr:sleep(20)
            end
        end
    end)

    --主线程等待完成
    for _ = 1, 30 do
        if #server_recvs >= ROUNDS and #client_recvs >= ROUNDS then break end
        thread_mgr:sleep(100)
    end

    self:report("udp rounds count", #client_recvs == ROUNDS, #client_recvs, ROUNDS)
    local all_ok = true
    for i = 1, ROUNDS do
        if server_recvs[i] ~= sformat("ping-%d", i) or client_recvs[i] ~= sformat("pong-%d", i) then
            all_ok = false
        end
    end
    self:report("udp all rounds matched", all_ok, all_ok, true)

    --全部往返完成后关闭端点, 结束 case
    pcall(function() client.close() end)
    pcall(function() server.close() end)
    log_info("[udp] rounds={}, closed", #client_recvs)
end

return UdpTest
