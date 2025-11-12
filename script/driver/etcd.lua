--etcd.lua
local log_err       = logger.err
local log_info      = logger.info
local log_debug     = logger.debug
local tunpack       = table.unpack
local sformat       = string.format
local qsurl         = qstring.url
local make_timer    = quanta.make_timer
local make_functer  = quanta.make_functer
local makechan      = quanta.make_channel
local grpccodec     = protobuf.grpccodec

local update_mgr    = quanta.get("update_mgr")
local protobuf_mgr  = quanta.get("protobuf_mgr")

local SocketH2      = import("driver/socketh2.lua")

local SECOND_MS     = quanta.enum("PeriodTime", "SECOND_MS")
local SECOND_10_MS  = quanta.enum("PeriodTime", "SECOND_10_MS")

local ETCD_NAMES    = { "watcher", "accessor" }

local Etcd = class()
local prop = property(Etcd)
prop:reader("ip", nil)          --ip
prop:reader("port", nil)        --port
prop:reader("scheme", nil)      --scheme
prop:reader("alives", {})       --alives
prop:reader("rcfunctor", nil)   --rcfunctor
prop:reader("connections", {})  --connections

function Etcd:__init(addr)
    self.timer = make_timer()
    self.gcodec = grpccodec()
    self.scheme, self.ip, self.port = qsurl(addr)
    self:setup()
end

function Etcd:close()
    for _, socket in pairs(self.alives) do
        socket:close()
    end
    for _, socket in pairs(self.connections) do
        socket:close()
    end
    self.timer:unregister()
end

function Etcd:setup()
    update_mgr:attach_hour(self)
    protobuf_mgr:load_file("proto/etcd.pb")
    for _, name in ipairs(ETCD_NAMES) do
        local socket = SocketH2(self)
        socket:options("grpc", self.scheme == "https")
        self.connections[name] = socket
        socket.name = name
    end
    self.rcfunctor = make_functer(self.check_alive)
    self.timer:loop(SECOND_MS, function()
        self.rcfunctor:call(self)
    end)
end

function Etcd:on_hour()
    for _, socket in pairs(self.alives) do
        socket:ping()
    end
end

function Etcd:check_alive()
    if next(self.connections) then
        local channel = makechan("check etcd")
        for name, socket in pairs(self.connections) do
            channel:push(function()
                return self:login(socket, name)
            end)
        end
        if channel:execute(true) then
            self.timer:change_period(SECOND_10_MS)
        end
    end
end

function Etcd:login(socket, name)
    local ok, err = socket:connect(self.ip, self.port)
    if not ok then
        log_err("[Etcd][login] connect: {}:{}:{} failed, err={}", self.ip, self.port, name, err)
        return false
    end
    log_info("[Etcd][login] login etcd({}:{}:{}) success!", self.ip, self.port, name)
    socket:set_content_codec("application/grpc", self.gcodec)
    self.connections[name] = nil
    self.alives[name] = socket
    return true
end

function Etcd:on_socket_error(socket, token, err)
    log_debug("[Etcd][on_socket_error] client(token:{}) close({})!", token, err)
    self.alives[socket.name] = socket
    self.connections[socket.name] = socket
    self.timer:change_period(SECOND_MS)
end

function Etcd:on_socket_recv(socket, errcode, status, headers, body)
    if errcode > 0 or status ~= 200 then
        log_debug("[Etcd][on_socket_recv] token:{} errcode:{}, status:{}!", socket.token, errcode, status)
        return
    end
    log_debug("[Etcd][on_socket_recv] token:{} body:{}, headers:{}!", socket.token, headers, body)
end

function Etcd:send_packet(socket, path, rpc, datas)
    local headers = {
        ["x-grpc-input"] = rpc.input_type,
        ["x-grpc-output"] = rpc.output_type,
        ["Content-Type"] = "application/grpc",
    }
    local ok, status, body, rheaders = socket:send_packet(path, rpc.method, headers, datas)
    if ok and status == 200 then
        return true, body
    end
    return false, status, rheaders
end

local interfaces = {
    get         = { "accessor", "etcdserverpb.KV", "Range" },
    put         = { "accessor", "etcdserverpb.KV", "Put" },
    compact     = { "accessor", "etcdserverpb.KV", "Compact" },
    delete      = { "accessor", "etcdserverpb.KV", "DeleteRange" },
    watch       = { "watcher",  "etcdserverpb.Watch", "Watch" },
    lease       = { "accessor", "etcdserverpb.Lease", "LeaseGrant" },
    revoke      = { "accessor", "etcdserverpb.Lease", "LeaseRevoke" },
    keepalive   = { "accessor", "etcdserverpb.Lease", "LeaseKeepAlive" },
    ttl         = { "accessor", "etcdserverpb.Lease", "LeaseTimeToLive" },
    leases      = { "accessor", "etcdserverpb.Lease", "LeaseLeases" },
}

for func, info in pairs(interfaces) do
    local sock_name, service, method = tunpack(info)
    local path = sformat("/%s/%s", service, method)
    Etcd[func] = function(self, req)
        local socket = self.alives[sock_name]
        if not socket then
            return false, "etcd socket not found"
        end
        local rpc = protobuf_mgr:get_service(service, method)
        if rpc then
            local ok, res, rheaders  = self:send_packet(socket, path, rpc, req)
            if ok then
                res.header = nil
                return ok, res
            end
            return ok, res, rheaders
        end
        return false, "etcd service not found"
    end
end

return Etcd
