-- ws_test.lua

local log_info      = logger.info
local sformat       = string.format

local event_mgr     = quanta.get("event_mgr")
local thread_mgr    = quanta.get("thread_mgr")

local PORT          = 29125
local ROUNDS        = 5

local TestCase      = import("test/case.lua")
local WSServer      = import("network/ws_server.lua")
local WSClient      = import("network/ws_client.lua")

local WsTest        = class(TestCase)

--服务端回调: 收到消息 echo 回去
function WsTest:on_socket_cmd(session, msg)
    if self.ws_server then
        self.ws_server:send(session, msg)
    end
end

--客户端回调: WSClient 在握手完成后直接调 host:on_socket_connect
function WsTest:on_socket_connect(session, token)
    self.ws_connected = true
end

--客户端收到 echo(经 event_mgr 派发)
function WsTest:on_socket_recv(session, msg)
    --注意: Lua pattern 中 '-' 是特殊字符, 必须转义为 '%-'
    local idx = tonumber(tostring(msg):match("echo%-(%d+)"))
    if idx then self.ws_recvs[idx] = msg end
end

function WsTest:on_client_error(session, token, err)
    log_info("[ws] client error: {}, {}", token, err)
end

function WsTest:run()
    self.ws_recvs = {}
    self.ws_connected = false

    --服务端
    event_mgr:listen_event(self, "on_socket_cmd")
    self.ws_server = WSServer()
    local ok, err = self.ws_server:listen("127.0.0.1", PORT)
    self:report("ws server listen", ok ~= false, err, "ok")
    if ok == false then return end

    --客户端(用同一个 self 作为 host, 但事件名与服务端不同)
    event_mgr:listen_event(self, "on_socket_recv")
    event_mgr:listen_event(self, "on_socket_error", "on_client_error")
    self.ws_client = WSClient(self)

    --case:execute 已运行在 thread_mgr:fork 协程中, connect 内部用 yield, 可直接调用
    local cok, cerr = self.ws_client:connect(sformat("127.0.0.1:%d", PORT))
    self:report("ws connect", cok == true, cerr, true)
    if cok ~= true then return end

    --握手后 session codec 在下一帧才切换为 wcodec, 等待 1000ms 再发送
    thread_mgr:sleep(1000)

    --串行发 ROUNDS 次, 每次等 echo
    for i = 1, ROUNDS do
        self.ws_client:send(sformat("echo-%d", i))
        for _ = 1, 100 do
            if self.ws_recvs[i] then break end
            thread_mgr:sleep(20)
        end
    end

    self:report("ws connected", self.ws_connected, self.ws_connected, true)
    self:report("ws rounds count", #self.ws_recvs == ROUNDS, #self.ws_recvs, ROUNDS)
    local all_ok = true
    for i = 1, ROUNDS do
        if self.ws_recvs[i] ~= sformat("echo-%d", i) then all_ok = false end
    end
    self:report("ws all rounds matched", all_ok, all_ok, true)

    --关闭连接, 结束 case
    self.ws_client:close()
    log_info("[ws] rounds={}, closed", #self.ws_recvs)
end

return WsTest
