local lcrypt            = require("lcrypt")
local log_err           = logger.err
local qxpcall           = quanta.xpcall
local env_status        = environ.status

local socket_mgr        = quanta.get("socket_mgr")
local thread_mgr        = quanta.get("thread_mgr")
local protobuf_mgr      = quanta.get("protobuf_mgr")
local perfeval_mgr      = quanta.get("perfeval_mgr")
local statis_mgr        = quanta.get("statis_mgr")

local FlagMask          = enum("FlagMask")
local NetwkTime         = enum("NetwkTime")

local out_press         = env_status("QUANTA_OUT_PRESS")
local out_encrypt       = env_status("QUANTA_OUT_ENCRYPT")

local NetClient = class()
local prop = property(NetClient)
prop:accessor("ip", nil)
prop:accessor("port", nil)
prop:accessor("alive", false)
prop:accessor("socket", nil)           --连接成功对象
prop:accessor("holder", nil)           --持有者
prop:accessor("decoder", nil)          --解码函数
prop:accessor("encoder", nil)          --编码函数
prop:accessor("wait_list", {})         --等待协议列表

function NetClient:__init(holder, ip, port)
    self.holder = holder
    self.port = port
    self.ip = ip
end

-- 发起连接
function NetClient:connect(block)
    --log_debug("[NetClient][connect] try connect: %s-%d", self.ip, self.port)
    if self.socket then
        return true
    end
    if not self.ip or not self.port then
        log_err("[NetClient][connect] try connect: ip:%s or port: %d is nil", self.ip, self.port)
        return false
    end
    local listen_proto_type = 1
    local socket = socket_mgr.connect(self.ip, self.port, NetwkTime.CONNECT_TIMEOUT, listen_proto_type)
    --设置阻塞id
    local block_id = block and thread_mgr:build_session_id()
    -- 调用成功，开始安装回调函数
    socket.on_connect = function(res)
        local succes = (res == "ok")
        local function dispatch_connect()
            if not succes then
                self:on_socket_err(socket, res)
                return
            end
            self:on_socket_connect(socket)
        end
        thread_mgr:fork(dispatch_connect)
        if block_id then
            --阻塞回调
            thread_mgr:response(block_id, succes, res)
        end
    end
    socket.on_call_dx = function(recv_len, cmd_id, flag, session_id, data)
        statis_mgr:statis_notify("on_dx_recv", cmd_id, recv_len)
        qxpcall(self.on_socket_rpc, "on_socket_rpc: %s", self, socket, cmd_id, flag, session_id, data)
    end
    socket.on_error = function(err)
        local function dispatch_err()
            self:on_socket_err(socket, err)
        end
        thread_mgr:fork(dispatch_err)
    end
    self.socket = socket
    --阻塞模式挂起
    if block_id then
        return thread_mgr:yield(block_id, "connect", NetwkTime.CONNECT_TIMEOUT)
    end
    return true
end

function NetClient:get_token()
    return self.socket and self.socket.token
end

function NetClient:encode(cmd_id, data, flag)
    local encode_data
    if self.encoder then
        encode_data = self.encoder(cmd_id, data)
    else
        encode_data = protobuf_mgr:encode(cmd_id, data)
    end
    if encode_data then
        -- 加密处理
        if out_encrypt then
            encode_data = lcrypt.b64_encode(encode_data)
            flag = flag | FlagMask.ENCRYPT
        end
        -- 压缩处理
        if out_press then
            encode_data = lcrypt.lz4_encode(encode_data)
            flag = flag | FlagMask.ZIP
        end
    end
    return encode_data, flag
end

function NetClient:decode(cmd_id, data, flag)
    local decode_data, cmd_name
    if self.decoder then
        decode_data, cmd_name = self.decoder(cmd_id, data)
    else
        decode_data, cmd_name = protobuf_mgr:decode(cmd_id, data)
    end
    if decode_data then
        --解压处理
        if flag & FlagMask.ZIP == FlagMask.ZIP then
            decode_data = lcrypt.lz4_decode(decode_data)
        end
        --解密处理
        if flag & FlagMask.ENCRYPT == FlagMask.ENCRYPT then
            decode_data = lcrypt.b64_decode(decode_data)
        end
    end
    return decode_data, cmd_name
end

function NetClient:on_socket_rpc(socket, cmd_id, flag, session_id, data)
    socket.alive_time = quanta.now
    local body, cmd_name = self:decode(cmd_id, data, flag)
    if not body  then
        log_err("[NetClient][on_socket_rpc] decode failed! cmd_id:%s，data:%s", cmd_id, data)
        return
    end
    if session_id == 0 or (flag & FlagMask.REQ == FlagMask.REQ) then
        -- 执行消息分发
        local function dispatch_rpc_message()
            local eval = perfeval_mgr:begin_eval(cmd_name)
            self.holder:on_socket_rpc(self, cmd_id, body, session_id)
            perfeval_mgr:end_eval(eval)
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

function NetClient:write(cmd_id, data, session_id, flag)
    if not self.alive then
        return false
    end
    local body, pflag = self:encode(cmd_id, data, flag)
    if not body then
        log_err("[NetClient][send_dx] encode failed! cmd_id:%s", cmd_id)
        return false
    end
    -- call lbus
    local send_len = self.socket.call_dx(cmd_id, pflag, session_id or 0, body)
    if send_len < 0 then
        log_err("[NetClient][write] call_dx failed! code:%s", send_len)
        return false
    end
    return true
end

-- 发送数据
function NetClient:send_dx(cmd_id, data, session_id)
    return self:write(cmd_id, data, session_id, FlagMask.REQ)
end

-- 回调数据
function NetClient:callback_dx(cmd_id, data, session_id)
    return self:write(cmd_id, data, session_id, FlagMask.RES)
end

-- 发起远程调用
function NetClient:call_dx(cmd_id, data)
    local session_id = thread_mgr:build_session_id()
    if not self:write(cmd_id, data, session_id, FlagMask.REQ) then
        return false
    end
    return thread_mgr:yield(session_id, cmd_id, NetwkTime.RPC_CALL_TIMEOUT)
end

-- 等待远程调用
function NetClient:wait_dx(cmd_id, time)
    local session_id = thread_mgr:build_session_id()
    self.wait_list[cmd_id] = session_id
    return thread_mgr:yield(session_id, cmd_id, time)
end

-- 连接成回调
function NetClient:on_socket_connect(socket)
    self.alive = true
    socket.alive_time = quanta.now
    self.holder:on_socket_connect(self)
end

-- 连接关闭回调
function NetClient:on_socket_err(socket, err)
    self.socket = nil
    self.alive = false
    self.wait_list = {}
    self.holder:on_socket_err(self, err)
end

return NetClient
