--net_client.lua

local log_err           = logger.err
local log_fatal         = logger.fatal
local qeval             = quanta.eval
local qxpcall           = quanta.xpcall

local event_mgr         = quanta.get("event_mgr")
local socket_mgr        = quanta.get("socket_mgr")
local thread_mgr        = quanta.get("thread_mgr")
local proxy_agent       = quanta.get("proxy_agent")

local proto_pb          = luabus.eproto_type.pb

local FLAG_REQ          = quanta.enum("FlagMask", "REQ")
local CONNECT_TIMEOUT   = quanta.enum("NetwkTime", "CONNECT_TIMEOUT")
local RPC_CALL_TIMEOUT  = quanta.enum("NetwkTime", "RPC_CALL_TIMEOUT")

local NetClient = class()
local prop = property(NetClient)
prop:reader("ip", nil)
prop:reader("port", nil)
prop:reader("codec", nil)
prop:reader("alive", false)
prop:reader("socket", nil)          --连接成功对象
prop:reader("holder", nil)          --持有者
prop:reader("wait_list", {})        --等待协议列表

function NetClient:__init(holder, ip, port)
    self.ip = ip
    self.port = port
    self.holder = holder
    self.codec = protobuf.pbcodec("ncmd_cs", "ncmd_cs.NCmdId")
end

-- 发起连接
function NetClient:connect(block)
    if self.socket then
        return true
    end
    local socket, cerr = socket_mgr.connect(self.ip, self.port, CONNECT_TIMEOUT, proto_pb)
    if not socket then
        log_err("[NetClient][connect] failed to connect: %s:%s err=%s", self.ip, self.port, cerr)
        return false, cerr
    end
    --设置阻塞id
    local block_id = block and thread_mgr:build_session_id()
    -- 调用成功，开始安装回调函数
    socket.set_codec(self.codec)
    socket.on_connect = function(res)
        local success = (res == "ok")
        thread_mgr:fork(function()
            if not success then
                self:on_socket_error(socket.token, res)
            else
                self:on_socket_connect(socket)
            end
        end)
        if block_id then
            --阻塞回调
            thread_mgr:response(block_id, success, res)
        end
    end
    socket.on_call_pb = function(recv_len, session_id, cmd_id, flag, type, crc8, body)
        proxy_agent:statistics("on_proto_recv", cmd_id, recv_len)
        qxpcall(self.on_socket_rpc, "on_socket_rpc: %s", self, socket, cmd_id, flag, type, session_id, body)
    end
    socket.on_error = function(token, err)
        thread_mgr:fork(function()
            self:on_socket_error(token, err)
        end)
    end
    self.socket = socket
    --阻塞模式挂起
    if block_id then
        return thread_mgr:yield(block_id, "connect", CONNECT_TIMEOUT)
    end
    return true
end

function NetClient:get_token()
    return self.socket and self.socket.token
end

function NetClient:on_socket_rpc(socket, cmd_id, flag, type, session_id, body)
    event_mgr:notify_trigger("on_message_recv", cmd_id, body)
    if session_id == 0 or (flag & FLAG_REQ == FLAG_REQ) then
        -- 执行消息分发
        local function dispatch_rpc_message()
            local _<close> = qeval(cmd_id)
            self.holder:on_socket_rpc(self, cmd_id, body, session_id)
        end
        thread_mgr:fork(dispatch_rpc_message)
        --等待协议处理
        local wait_session_id = self.wait_list[cmd_id]
        if wait_session_id then
            self.wait_list[cmd_id] = nil
            thread_mgr:response(wait_session_id, true)
        end
        return
    end
    --异步回执
    thread_mgr:response(session_id, true, body)
end

-- 主动关闭连接
function NetClient:close()
    if self.socket then
        self.socket.close()
        self.alive = false
        self.socket = nil
    end
end

function NetClient:write(cmd, data, type, session_id, flag)
    if not self.alive then
        return false
    end
    local body, cmd_id, pflag = self:encode(cmd, data, flag)
    if not body then
        log_fatal("[NetClient][write] encode failed! data (%s-%s)", cmd_id, body)
        return false
    end
    -- call lbus
    local send_len = self.socket.call_pb(cmd_id, pflag, type, session_id, data)
    if send_len < 0 then
        log_err("[NetClient][write] call_pb failed! code:%s", send_len)
        return false
    end
    proxy_agent:statistics("on_proto_send", cmd_id, send_len)
    return true
end

-- 发送数据
function NetClient:send(cmd_id, data, type)
    return self:write(cmd_id, data, type or 0, 0, FLAG_REQ)
end

-- 发起远程命令
function NetClient:call(cmd_id, data, type)
    if not self.alive then
        return false
    end
    local session_id = self.socket.build_session_id()
    if not self:write(cmd_id, data, type or 0, session_id, FLAG_REQ) then
        return false
    end
    return thread_mgr:yield(session_id, cmd_id, RPC_CALL_TIMEOUT)
end

-- 等待NTF命令或者非RPC命令
function NetClient:wait(cmd_id, time)
    local session_id = thread_mgr:build_session_id()
    self.wait_list[cmd_id] = session_id
    return thread_mgr:yield(session_id, cmd_id, time)
end

-- 连接成回调
function NetClient:on_socket_connect(socket)
    self.alive = true
    self.holder:on_socket_connect(self)
end

-- 连接关闭回调
function NetClient:on_socket_error(token, err)
    if self.socket then
        self.socket = nil
        self.alive = false
        self.wait_list = {}
        self.holder:on_socket_error(self, token, err)
    end
end

return NetClient
