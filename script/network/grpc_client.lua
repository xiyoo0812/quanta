--grpc_client.lua
local log_err       = logger.err
local log_debug     = logger.debug
local qsurl         = qstring.url
local make_timer    = quanta.make_timer
local make_functer  = quanta.make_functer
local grpccodec     = protobuf.grpccodec

local update_mgr    = quanta.get("update_mgr")

local SocketH2      = import("driver/socketh2.lua")

local SECOND_MS     = quanta.enum("PeriodTime", "SECOND_MS")
local SECOND_10_MS  = quanta.enum("PeriodTime", "SECOND_10_MS")

local GrpcClient = class()
local prop = property(GrpcClient)
prop:reader("ip", nil)          --ip
prop:reader("port", nil)        --port
prop:reader("scheme", nil)      --scheme
prop:reader("timer", nil)       --timer
prop:reader("gcodec", nil)      --gcodec
prop:reader("socket", nil)      --socket
prop:reader("rcfunctor", nil)   --rcfunctor
prop:reader("connector", nil)   --connector

function GrpcClient:__init(addr)
    self.timer = make_timer()
    self.gcodec = grpccodec()
    self.connector = SocketH2(self)
    self.scheme, self.ip, self.port = qsurl(addr)
    self.connector:options("grpc", self.scheme == "https")
    --attach_hour
    update_mgr:attach_hour(self)
    --timer
    self.rcfunctor = make_functer(self.check_alive)
    self.timer:loop(SECOND_MS, function()
        self.rcfunctor:call(self)
    end)
end

function GrpcClient:close()
    local socket = self.socket or self.connector
    self.timer:unregister()
    socket:close()
end

function GrpcClient:on_hour()
    if self.socket then
        self.socket:ping()
    end
end

function GrpcClient:check_alive()
    if self.connector then
        self:connect()
    end
end

function GrpcClient:on_socket_recv(socket, ...)
    log_debug("[GrpcClient][on_socket_recv] client(token:{}) args({})!", socket.token, { ... })
end

function GrpcClient:on_socket_error(socket, token, err)
    log_debug("[GrpcClient][on_socket_error] client(token:{}) close({})!", token, err)
    self.socket = nil
    self.connector = socket
    self.timer:change_period(SECOND_MS)
end

function GrpcClient:connect()
    local socket = self.connector
    local ok, err = socket:connect(self.ip, self.port)
    if not ok then
        log_err("[GrpcClient][connect] failed to connect: {}:{} err={}", self.ip, self.port, err)
        return false, err
    end
    socket:set_content_codec("application/grpc", self.gcodec)
    self.timer:change_period(SECOND_10_MS)
    self.socket = socket
    self.connector = nil
    return true
end

function GrpcClient:send_packet(path, rpc, datas)
    if self.socket then
        local headers = {
            ["x-grpc-input"] = rpc.input_type,
            ["x-grpc-output"] = rpc.output_type,
            ["Content-Type"] = "application/grpc",
        }
        local ok, status, body, rheaders = self.socket:send_packet(path, rpc.method, headers, datas)
        if ok and status == 200 then
            return true, body
        end
        return false, status, rheaders
    end
    return false, "socket not alive"
end

return GrpcClient
