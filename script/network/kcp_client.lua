--kcp_client.lua

local log_err           = logger.err
local log_warn          = logger.warn
local lnext_id          = luakit.next_id
local kcp_update        = kcp.update
local kcp_connect       = kcp.connect

local FLAG_REQ          = luabus.proto_flag.REQ
local FLAG_BAD          = luabus.proto_flag.BAD
local FLAG_UNREACH      = luabus.proto_flag.UNREACH

local event_mgr         = quanta.get("event_mgr")
local update_mgr        = quanta.get("update_mgr")
local thread_mgr        = quanta.get("thread_mgr")

local Message           = import("feature/message_pb.lua")

local UNREACHABLE       = quanta.enum("KernCode", "UNREACHABLE")
local PARAM_ERROR       = quanta.enum("KernCode", "PARAM_ERROR")
local RPC_CALL_TIMEOUT  = quanta.enum("NetwkTime", "RPC_CALL_TIMEOUT")

local KcpClient = class()
local prop = property(KcpClient)
prop:reader("ip", nil)
prop:reader("port", nil)
prop:reader("codec", nil)
prop:reader("alive", false)
prop:reader("socket", nil)          --连接成功对象
prop:reader("wait_list", {})        --等待协议列表

function KcpClient:__init(ip, port)
    self.ip = ip
    self.port = port
    self.codec = protobuf.pbcodec()
    update_mgr:attach_quit(self)
    update_mgr:attach_frame(self)
end

function KcpClient:on_quit()
    self:close()
end

function KcpClient:on_frame(clock_ms)
    kcp_update(clock_ms)
end

function KcpClient:dispatch_wait(cmd_id, body)
    local wait_session_id = self.wait_list[cmd_id]
    if wait_session_id then
        self.wait_list[cmd_id] = nil
        thread_mgr:response(wait_session_id, true, body)
    end
end

function KcpClient:dispatch_pb_message(socket, message, cmd_id, session_id)
    if session_id == 0 then
        -- 事件分发
        event_mgr:notify_pb_message(cmd_id, socket, message, message.request)
    else
        --异步回调
        thread_mgr:response(session_id, true, message.request)
    end
end

function KcpClient:dispatch_message(socket, message, cmd_id, session_id, flag)
    -- 事件统计
    event_mgr:notify_trigger("on_recv_kcp_message", message)
    -- 错误处理
    if flag == FLAG_UNREACH or flag == FLAG_BAD then
        log_err("[KcpClient][dispatch_message] cmd_id {} is unreachable in router!", cmd_id)
        if session_id > 0 then
            local code = flag == FLAG_UNREACH and UNREACHABLE or PARAM_ERROR
            thread_mgr:response(session_id, false, code, "target is unreachable!")
        end
        return
    end
    -- 事件分发
    self:dispatch_pb_message(socket, message, cmd_id, session_id)
    self:dispatch_wait(cmd_id, message.request)
end

-- 发起连接
function KcpClient:connect()
    if self.socket then
        return true
    end
    local socket = kcp_connect(self.ip, self.port)
    if not socket then
        log_err("[KcpClient][connect] failed to connect: {}:{}", self.ip, self.port)
        return false, "connect failed"
    end
    -- 调用成功，开始安装回调函数
    socket.set_codec(self.codec)
    socket.call_client = function(cmd_id, flag, type, session_id, target_id, body)
        if not self.alive then
            log_err("[KcpClient][call_client] session lost! cmd_id:{}-({})", cmd_id, body)
            return false
        end
        local send_len = socket.send_kcp(session_id, cmd_id, flag, type, target_id, body)
        if send_len <= 0 then
            log_err("[KcpClient][call_client] send_kcp failed! code:{}", send_len)
            return false
        end
        event_mgr:notify_trigger("on_send_kcp_message", cmd_id, body, send_len)
        return true
    end
    socket.on_call = function(recv_len, session_id, target_id, cmd_id, flag, body, err)
        if body then
            local message = Message(socket, session_id, recv_len, body, cmd_id, flag, target_id)
            thread_mgr:fork(self.dispatch_message, nil, self, socket, message, cmd_id, session_id, flag)
            return
        end
        log_warn("[KcpClient][on_call] pb cmd_id({}) decode field: {}!", cmd_id, err and err or "pb not define")
    end
    socket.on_error = function(token, err)
        thread_mgr:fork(function()
            self:on_socket_error(token, err)
        end)
    end
    self.socket = socket
    self.alive = true
    return true
end

function KcpClient:get_token()
    return self.socket and self.socket.token
end

-- 主动关闭连接
function KcpClient:close()
    if self.socket then
        self.socket.close()
        self.socket = nil
        self.alive = false
    end
end

function KcpClient:output(cmd_id, data, type, session_id, flag, target_id)
    local ok = self.socket.call_client(cmd_id, flag, type, session_id, target_id, data)
    if not ok then
        return false
    end
    if not session_id or session_id <= 0 then
        return true
    end
    return thread_mgr:yield(session_id, cmd_id, RPC_CALL_TIMEOUT)
end

-- 发送数据
function KcpClient:send(cmd_id, data, type)
    return self:output(cmd_id, data, type or 0, 0, FLAG_REQ, 0)
end

-- 发起远程命令
function KcpClient:call(cmd_id, data, type)
    local session_id = lnext_id() & 0xffff
    return self:output(cmd_id, data, type or 0, session_id, FLAG_REQ, 0)
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
        log_err("[KcpClient][on_socket_error] session: {} lost, because: {}!", token, err)
        self.socket = nil
        self.wait_list = {}
        self.alive = false
    end
end

return KcpClient
