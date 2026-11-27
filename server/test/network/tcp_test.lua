-- tcp_test.lua
local log_info      = logger.info
local sformat       = string.format

local thread_mgr    = quanta.get("thread_mgr")

local PORT          = 28700     --测试端口, 避免与其它用例冲突
local ROUNDS        = 5         --往返次数(串行: 发一条等回复再发下一条, 避免TCP粘包)

local TestCase      = import("test/case.lua")
local TcpTest       = class(TestCase)

function TcpTest:run()
    local tcp = luabus.tcp(true)
    local ok, err = tcp.listen("127.0.0.1", PORT)
    self:report("tcp listen", ok == true, err, "ok")
    if not ok then return end

    local server_recvs = {}    --server 端收到的消息列表
    local client_recvs = {}    --client 端收到的回复列表
    local server_conn = nil
    local client_conn = nil

    --server 协程: accept + 循环收 ROUNDS 次并逐条回包
    thread_mgr:fork(function()
        for _ = 1, 50 do
            server_conn = tcp.accept(100, true)
            if server_conn then break end
            thread_mgr:sleep(20)
        end
        if not server_conn then return end
        for i = 1, ROUNDS do
            for _ = 1, 50 do
                local rok, buf = server_conn.recv()
                if rok then
                    server_recvs[i] = buf
                    local reply = sformat("pong-%d", i)
                    server_conn.send(reply, #reply)
                    break
                end
                thread_mgr:sleep(20)
            end
        end
    end)

    --client 协程: connect + 串行发 ROUNDS 次, 每次等回复
    thread_mgr:fork(function()
        for _ = 1, 50 do
            client_conn = luabus.tcp(true)
            local cok = client_conn.connect("127.0.0.1", PORT, 100)
            if cok then break end
            thread_mgr:sleep(20)
        end
        if not client_conn then return end
        for i = 1, ROUNDS do
            local data = sformat("ping-%d", i)
            client_conn.send(data, #data)
            for _ = 1, 50 do
                local rok, buf = client_conn.recv()
                if rok then
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

    self:report("tcp rounds count", #client_recvs == ROUNDS, #client_recvs, ROUNDS)
    local all_ok = true
    for i = 1, ROUNDS do
        if server_recvs[i] ~= sformat("ping-%d", i) or client_recvs[i] ~= sformat("pong-%d", i) then
            all_ok = false
        end
    end
    self:report("tcp all rounds matched", all_ok, all_ok, true)

    --全部往返完成后关闭连接, 结束 case
    if client_conn then client_conn.close() end
    if server_conn then server_conn.close() end
    log_info("[tcp] rounds={}, closed", #client_recvs)
end

return TcpTest
