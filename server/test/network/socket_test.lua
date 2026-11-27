-- socket_test.lua
local json        = require("ljson")
local jsoncodec   = json.jsoncodec
local log_info    = logger.info

local thread_mgr  = quanta.get("thread_mgr")

local PORT        = 28500
local ROUNDS      = 5

local TestCase    = import("test/case.lua")
local Socket      = import("driver/socket.lua")
local SocketTest  = class(TestCase)

--handler 用普通 table(每个文件只允许一个 class, 这里不再用 class())
local function make_handler(name, server, on_result)
    local obj = { codec = jsoncodec(), server = server, name = name }
    function obj:on_socket_accept(socket, token)
        socket:set_codec(self.codec)
    end
    function obj:on_socket_recv(socket, data)
        if self.server then
            --服务端收到: 回一条固定消息
            socket:send_data({ msg = "pong-from-server", index = data.index or 0 })
        else
            --客户端收到回复
            on_result(data)
        end
    end
    function obj:on_socket_error(socket, token, err)
        log_info("[socket][{}] error: {}, {}", self.name, token, err)
    end
    return obj
end

function SocketTest:run()
    local client_recvs = {}    --客户端收到的回复列表
    local server_sock = nil
    local client_sock = nil

    --server: 监听 + 收消息后回复
    thread_mgr:fork(function()
        server_sock = Socket(make_handler("socket-svr", true, nil))
        local ok, err = server_sock:listen("127.0.0.1", PORT)
        self:report("socket server listen", ok == true, err, "ok")
        if not ok then return end
        --保持协程存活以处理回调
        for _ = 1, 30 do thread_mgr:sleep(100) end
    end)

    --client: 连接 + 发消息 + 等回复
    thread_mgr:fork(function()
        client_sock = Socket(make_handler("socket-cli", false, function(data)
            if data and data.index then
                client_recvs[data.index] = data
            end
        end))
        local ok, err = client_sock:connect("127.0.0.1", PORT)
        self:report("socket client connect", ok == true, err, "ok")
        if not ok then return end
        client_sock:set_codec(jsoncodec())
        --串行发 ROUNDS 次, 每次等回复
        for i = 1, ROUNDS do
            client_sock:send_data({ msg = "ping-from-client", index = i })
            for _ = 1, 30 do
                if client_recvs[i] then break end
                thread_mgr:sleep(50)
            end
        end
    end)

    --主线程等待完成
    for _ = 1, 30 do
        if #client_recvs >= ROUNDS then break end
        thread_mgr:sleep(100)
    end

    self:report("socket rounds count", #client_recvs == ROUNDS, #client_recvs, ROUNDS)
    local all_ok = true
    for i = 1, ROUNDS do
        if not client_recvs[i] or client_recvs[i].msg ~= "pong-from-server" or client_recvs[i].index ~= i then
            all_ok = false
        end
    end
    self:report("socket all rounds matched", all_ok, all_ok, true)

    --全部往返完成后关闭连接, 结束 case
    if client_sock then client_sock:close() end
    if server_sock then server_sock:close() end
    log_info("[socket] rounds={}, connections closed", #client_recvs)
end

return SocketTest
