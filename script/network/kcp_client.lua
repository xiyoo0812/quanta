--kcp_client.lua

local log_err           = logger.err
local qdefer            = quanta.defer
local qxpcall           = quanta.xpcall
local lnext_id          = luakit.next_id
local kcp_update        = kcp.update

local event_mgr         = quanta.get("event_mgr")
local update_mgr        = quanta.get("update_mgr")
local thread_mgr        = quanta.get("thread_mgr")

local FLAG_REQ          = quanta.enum("FlagMask", "REQ")
local RPC_CALL_TIMEOUT  = quanta.enum("NetwkTime", "RPC_CALL_TIMEOUT")

local KcpClient = class()
local prop = property(KcpClient)
prop:reader("ip", nil)
prop:reader("port", nil)
prop:reader("codec", nil)
prop:reader("socket", nil)          --连接成功对象
prop:reader("holder", nil)          --持有者
prop:reader("wait_list", {})        --等待协议列表

function KcpClient:__init(holder, ip, port)
    self.ip = ip
    self.port = port
    self.holder = holder
    self.codec = protobuf.pbcodec()
    --注册更新函数
    update_mgr:register_frame("kcp_update", function(clock_ms)
        kcp_update(clock_ms)
    end)
end

-- 发起连接
function KcpClient:connect()
    if self.socket then
        return true
    end
    local socket = kcp.connect(self.ip, self.port)
    if not socket then
        log_err("[KcpClient][connect] failed to connect: {}:{}", self.ip, self.port)
        return false, "connect failed"
    end
    -- 调用成功，开始安装回调函数
    socket.set_codec(self.codec)
    socket.on_call = function(recv_len, session_id, cmd_id, flag, type, crc8, body)
        qxpcall(self.on_socket_rpc, "on_socket_rpc: {}", self, cmd_id, flag, session_id, body)
    end
    socket.on_error = function(token, err)
        thread_mgr:fork(function()
            self:on_socket_error(token, err)
        end)
    end
    self.socket = socket
    return true
end

function KcpClient:get_token()
    return self.socket and self.socket.token
end

function KcpClient:on_socket_rpc(cmd_id, flag, session_id, body)
    if session_id == 0 or (flag & FLAG_REQ == FLAG_REQ) then
        -- 执行消息分发
        local function dispatch_rpc_message()
            self.holder:on_socket_rpc(self, cmd_id, body, session_id)
            --等待协议处理
            event_mgr:notify_listener("on_recv_message", cmd_id, body)
            local wait_session_id = self.wait_list[cmd_id]
            if wait_session_id then
                self.wait_list[cmd_id] = nil
                thread_mgr:response(wait_session_id, true, body)
            end
        end
        thread_mgr:fork(dispatch_rpc_message)
        return
    end
    --异步回执
    thread_mgr:response(session_id, true, body)
end

-- 主动关闭连接
function KcpClient:close()
    if self.socket then
        self.socket.close()
        self.socket = nil
    end
end

function KcpClient:write(cmd_id, data, type, session_id, flag)
    if not self.socket then
        return false
    end
    local hook<close> = qdefer()
    event_mgr:execute_hook("on_ccmd_send", hook, cmd_id, data)
    -- call lbus
    local send_len = self.socket.send_kcp(session_id, cmd_id, flag, type, 0, data)
    if send_len <= 0 then
        log_err("[KcpClient][write] call_pb failed! code:{}", send_len)
        return false
    end
    if not session_id or session_id <= 0 then
        return true
    end
    return thread_mgr:yield(session_id, cmd_id, RPC_CALL_TIMEOUT)
end

-- 发送数据
function KcpClient:send(cmd_id, data, type)
    return self:write(cmd_id, data, type or 0, 0, FLAG_REQ)
end

-- 发起远程命令
function KcpClient:call(cmd_id, data, type)
    local session_id = lnext_id() & 0xffff
    return self:write(cmd_id, data, type or 0, session_id, FLAG_REQ)
end

-- 等待NTF命令或者非RPC命令
function KcpClient:wait(cmd_id, time)
    local session_id = lnext_id()
    self.wait_list[cmd_id] = session_id
    return thread_mgr:yield(session_id, cmd_id, time)
end

-- 连接关闭回调
function KcpClient:on_socket_error(token, err)
    if self.socket then
        self.socket = nil
        self.wait_list = {}
        self.holder:on_socket_error(self, token, err)
    end
end

return KcpClient
