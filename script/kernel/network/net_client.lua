-- @author: errorcpp@qq.com
-- @date:   2019-07-22

local log_err           = logger.err
local qxpcall           = quanta.xpcall

local socket_mgr        = quanta.socket_mgr
local thread_mgr        = quanta.thread_mgr
local protobuf_mgr      = quanta.protobuf_mgr
local perfeval_mgr      = quanta.perfeval_mgr
local statis_mgr        = quanta.statis_mgr

local CONNECT_WAIT_TIME = 3000
local NET_RPC_TIMEOUT   = 6000
local RPC_TYPE_REQ      = 0 --rpc 请求类型
local RPC_TYPE_RES      = 1 --rpc 响应类型

local NetClient = class()
local prop = property(NetClient)
prop:accessor("session", nil)       --连接成功对象
prop:accessor("decoder", nil)       --解码函数
prop:accessor("encoder", nil)       --编码函数
prop:accessor("wait_list", {})      --等待协议列表
prop:accessor("hb_req_id", 1001)    --心跳请求
prop:accessor("hb_ack_id", 1002)    --心跳回执
prop:accessor("serial", 0)          --心跳序列号

function NetClient:__init()
end

function NetClient:get_token()
    return self.session and self.session.token
end

-- 发起连接
function NetClient:connect(ip, port, block)
    --log_debug("NetClient:connect try connect: %s-%d", ip, port)
    if self.session then
        return true
    end
    local session, res = socket_mgr.connect(ip, port, CONNECT_WAIT_TIME, 1)

    -- 函数调用失败
    if not session then
        self:on_close(res)
        return false, res
    end

    self.session = session
    --设置阻塞id
    local block_id = block and thread_mgr:build_session_id()
    -- 调用成功，开始安装回调函数
    self.session.on_connect = function(result)
        local succes = (result == "ok")
        local function dispatch_connect()
            if not succes then
                self:on_close(result)
                return
            end
            self:on_connect()
        end
        thread_mgr:fork(dispatch_connect)
        if block_id then
            --阻塞回调
            thread_mgr:response(block_id, succes, result)
        end
    end

    self.session.on_call_dx = function(recv_len, cmd_id, flag, session_id, data)
        statis_mgr:statis_notify("on_dx_recv", cmd_id, recv_len)
        local eval = perfeval_mgr:begin_eval("dx_c_cmd_" .. cmd_id)
        qxpcall(self.on_call_dx, "on_call_dx: %s", self, cmd_id, flag, session_id, data)
        perfeval_mgr:end_eval(eval)
    end

    self.session.on_error = function(err)
        -- 执行消息分发
        local function dispatch_close()
            self:on_close(err)
        end
        thread_mgr:fork(dispatch_close)
    end
    --阻塞模式挂起
    if block_id then
        return thread_mgr:yield(block_id, CONNECT_WAIT_TIME)
    end
    return true
end

function NetClient:encode(cmd_id, data)
    if self.encoder then
        return self.encoder(cmd_id, data)
    end
    return protobuf_mgr:encode(cmd_id, data)
end

function NetClient:decode(cmd_id, data)
    if self.decoder then
        return self.decoder(cmd_id, data)
    end
    return protobuf_mgr:decode(cmd_id, data)
end

function NetClient:on_call_dx(cmd_id, flag, session_id, data)
    self.session.alive_time = quanta.now
    local body = self:decode(cmd_id, data)
    if not body  then
        log_err("[NetClient][on_call_dx] decode failed! cmd_id:%s，data:%s", cmd_id, data)
        return
    end
    -- 内核消息提前处理
    if cmd_id == self.hb_ack_id then
        self.serial = body.serial
        return
    end
    if session_id == 0 or flag == RPC_TYPE_REQ then
        -- 执行消息分发
        local function dispatch_rpc_message()
            self:on_recv(cmd_id, body, session_id)
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
    if self.session then
        self.session.close()
        self.serial = 0
    end
end

function NetClient:write(cmd_id, data, session_id, flag)
    if not self.session then
        return false
    end

    local body = self:encode(cmd_id, data)
    if not body then
        log_err("[NetClient][send_dx] encode failed! cmd_id:%s", cmd_id)
        return false
    end
    -- call lbus
    local session_id = session_id or 0
    local send_len = self.session.call_dx(cmd_id, flag or RPC_TYPE_REQ, session_id, body)
    if send_len < 0 then
        log_err("[NetClient][write] call_dx failed! code:%s", send_len)
        return false
    end
    return true
end

-- 发送数据
function NetClient:send_dx(cmd_id, data, session_id)
    return self:write(cmd_id, data, session_id)
end

-- 回调数据
function NetClient:callback_dx(cmd_id, data, session_id)
    return self:write(cmd_id, data, session_id, RPC_TYPE_RES)
end

-- 发起远程调用
function NetClient:call_dx(cmd_id, data)
    local session_id = thread_mgr:build_session_id()
    if not self:write(cmd_id, data, session_id) then
        return false
    end
    return thread_mgr:yield(session_id, NET_RPC_TIMEOUT)
end

-- 等待远程调用
function NetClient:wait_dx(cmd_id, time)
    local session_id = thread_mgr:build_session_id()
    self.wait_list[cmd_id] = session_id
    return thread_mgr:yield(session_id, time)
end

-- 连接成回调
function NetClient:on_connect()
    self:on_connect_impl()
end

-- 连接回调实现，用于派生类业务处理
function NetClient:on_connect_impl()

end

-- 数据回调
function NetClient:on_recv(cmd_id, body)
    --log_debug("NetClient:on_recv: token=%s, cmd=%d", self:get_token(), cmd_id)
end

-- 连接关闭回调
function NetClient:on_close(err)
    self.session = nil
    self.wait_list = {}
    self:on_close_impl(err)
end

-- 连接关闭回调实现，用于派生类业务处理
function NetClient:on_close_impl(err)

end

-- 发送心跳
function NetClient:send_hbbeat_req()
    self:send_dx(self.hb_req_id, {serial = self.serial})
end

return NetClient
