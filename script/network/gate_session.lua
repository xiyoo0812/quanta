--gate_session.lua

local log_err       = logger.err
local log_info      = logger.info

local event_mgr     = quanta.get("event_mgr")
local player_mgr    = quanta.get("player_mgr")
local thread_mgr    = quanta.get("thread_mgr")
local protobuf_mgr  = quanta.get("protobuf_mgr")

local GROUP         = luabus.relay_type.GROUP
local CLIENT        = luabus.relay_type.CLIENT
local BROADCAST     = luabus.relay_type.BROADCAST

local FLAG_REQ      = luabus.proto_flag.REQ

local FAST_MS       = quanta.enum("PeriodTime", "FAST_MS")
local SECOND_MS     = quanta.enum("PeriodTime", "SECOND_MS")
local SECOND_5_MS   = quanta.enum("PeriodTime", "SECOND_5_MS")

local FRAME_FAILED  = protobuf_mgr:error_code("FRAME_FAILED")

local TcpClient     = import("network/tcp_client.lua")

local GateSession = class(TcpClient)
local prop = property(GateSession)
prop:accessor("id", nil)

function GateSession:__init(ip, port, gateway_id)
    self.id = gateway_id
    -- 开始连接
    self:start()
end

function GateSession:relocation(ip, port)
    self.ip = ip
    self.port = port
    self.timer:register(FAST_MS, SECOND_MS, -1, function()
        self.functor:call(self)
    end)
end

function GateSession:dispatch_pb_message(socket, message, cmd_id, session_id)
    if message.flag & FLAG_REQ == FLAG_REQ then
        -- 事件分发
        local pbmessage<close> = message
        local player_id = message.target_id
        local player = player_mgr:get_entity(player_id)
        local nok, err = event_mgr:notify_pb_message(cmd_id, player or self, pbmessage, message.request, message.response, player_id)
        if not nok then
            log_err("[GateSession][dispatch_message] notify_pb_message failed! cmd_id:{}, err:{}", cmd_id, err)
            message:callback_code(FRAME_FAILED)
        end
    else
        --异步回调
        thread_mgr:response(session_id, true, message.request)
    end
end

function GateSession:on_socket_connected(socket)
    self.alive = true
    local ok, res = self:call("NID_GATE_BIND_SERVER_REQ", { server_id = quanta.id })
    if not ok or res.error_code ~= 0 then
        log_err("[GateSession][on_socket_connected] bind gateway: {} failed: {}", self.id, res)
        self:close()
        return false
    end
    log_info("[GateSession][on_socket_connected] bind gateway: {} success", self.id)
    self.timer:change_period(SECOND_5_MS)
    return true
end

function GateSession:bind_service(player_id)
    local data = { client_id = player_id, server_id = quanta.id, token = self.socket.token }
    local ok, res = self:call("NID_GATE_BIND_SERVICE_REQ", data)
    if not ok or res.error_code ~= 0 then
        log_err("[GateSession][bind_service] failed to bind service: {} err={}", player_id, res)
        return
    end
    log_info("[GateSession][bind_service] bind service: player_id {} success", player_id)
end

function GateSession:on_socket_error(token, err)
    TcpClient.on_socket_error(self, token, err)
    self.timer:change_period(SECOND_MS)
end

function GateSession:send_client(player_id, cmd_id, data)
    return self:output(cmd_id, data, CLIENT, 0, 0, player_id)
end

function GateSession:broadcast(cmd_id, data)
    return self:output(cmd_id, data, BROADCAST, 0, 0, 0)
end

function GateSession:group_send(group, cmd_id, data)
    return self:output(cmd_id, data, GROUP, 0, 0, group)
end

return GateSession
