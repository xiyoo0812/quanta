--etcd.lua
local tonumber      = tonumber
local log_err       = logger.err
local log_info      = logger.info
local log_warn      = logger.warn
local log_debug     = logger.debug
local tunpack       = table.unpack
local sformat       = string.format
local qsurl         = qstring.url
local make_timer    = quanta.make_timer
local make_functer  = quanta.make_functer
local grpccodec     = protobuf.grpccodec

local update_mgr    = quanta.get("update_mgr")
local protobuf_mgr  = quanta.get("protobuf_mgr")

local SocketH2      = import("driver/socketh2.lua")
local FAST_MS       = quanta.enum("PeriodTime", "FAST_MS")
local SECOND_MS     = quanta.enum("PeriodTime", "SECOND_MS")
local SECOND_10_MS  = quanta.enum("PeriodTime", "SECOND_10_MS")
local CONNECT_TO    = quanta.enum("NetwkTime", "CONNECT_TIMEOUT")

local Etcd = class()
local prop = property(Etcd)
prop:reader("ip", nil)          --ip
prop:reader("port", nil)        --port
prop:reader("scheme", nil)      --scheme
prop:reader("socket", nil)      --socket
prop:reader("rcfunctor", nil)   --rcfunctor
prop:reader("watchers", {})     --stream_id -> {callback, range_end, start_revision, last_revision}
prop:reader("watcher_idxs", {}) --key -> stream_id

function Etcd:__init(addr)
    self.timer = make_timer()
    self.gcodec = grpccodec()
    self.connecting = false
    self.scheme, self.ip, self.port = qsurl(addr)
    self:setup()
end

function Etcd:close()
    self.socket:close()
    self.timer:unregister()
end

function Etcd:setup()
    update_mgr:attach_hour(self)
    protobuf_mgr:load_file("proto/etcd.pb")
    self.socket = SocketH2(self)
    self.socket:options("grpc", self.scheme == "https")
    self.rcfunctor = make_functer("check_alive", CONNECT_TO)
    self.timer:register(FAST_MS, SECOND_MS, -1, function()
        self.rcfunctor:run(self)
    end)
end

function Etcd:on_hour()
    if self.socket:is_ready() then
        self.socket:ping()
    end
end

function Etcd:check_alive()
    if self.socket:is_ready() then
        return
    end
    if self:login() then
        self.timer:change_period(SECOND_10_MS)
    end
end

function Etcd:login()
    local ok, err = self.socket:connect(self.ip, self.port)
    if not ok then
        log_err("[Etcd][login] connect: {}:{}:{} failed, err={}", self.ip, self.port, err)
        return false
    end
    self.socket:set_content_codec("application/grpc", self.gcodec)
    log_info("[Etcd][login] login etcd({}:{} success!", self.ip, self.port)
    -- 恢复 watch
    local old_watchers = self.watchers
    self.watchers = {}
    for watch_id, watcher in pairs(old_watchers) do
        local wok, werr = self:watch(watcher.key, watcher.callback, watcher.range_end, watcher.start_revision, watcher.last_revision)
        if not wok then
            log_err("[Etcd][login] watch({}) recover failed: {}", watcher.key, werr)
        end
    end
    return true
end

function Etcd:on_socket_error(socket, token, err)
    log_debug("[Etcd][on_socket_error] client(token:{}) close({})!", token, err)
    self.timer:change_period(SECOND_MS)
    self.watcher_idxs = {}
end

--处理 watch 推送事件，只有watch推送会到这里
function Etcd:on_socket_recv(socket, stream_id, errcode, status, headers, body)
    if errcode > 0 or status ~= 200 then
        log_err("[Etcd][on_socket_recv] errcode:{}, status:{}", errcode, status)
        return
    end
    local watcher = self.watchers[stream_id]
    if watcher then
        if body.canceled == true then
            log_warn("[Etcd][on_socket_recv] watch({}) canceled: {}", watcher.key, body.cancel_reason)
            self.watcher_idxs[watcher.key] = nil
            self.watchers[stream_id] = nil
            return
        end
        local revision = body.header.revision
        if revision then
            watcher.last_revision = revision
        end
        local events = body.events
        if events and next(events) and watcher.callback then
            local ok, err = pcall(watcher.callback, events, body)
            if not ok then
                log_err("[Etcd][on_socket_recv] watch({}) callback failed: {}", watcher.key, err)
            end
        end
    end
end

function Etcd:watch(key, callback, range_end, start_revision, last_revision)
    local revision = last_revision and (last_revision + 1) or start_revision or 0
    local watcher = {
        key = key,
        callback = callback,
        range_end = range_end,
        start_revision = revision,
    }
    local req = { create_request = { key = key, start_revision = revision, range_end = range_end } }
    local ok, res, stream_id = self:watch_req(req)
    if ok and res.created then
        self.watchers[stream_id] = watcher
        self.watcher_idxs[key] = stream_id
        watcher.last_revision = res.header.revision
        log_info("[Etcd][watch] watch({}) created, stream_id({})", key, stream_id)
        return true
    end
    return false, ok and "watch failed" or res
end

function Etcd:unwatch(key)
    local stream_id = self.watcher_idxs[key]
    if not stream_id then
        return false, "watcher not found"
    end
    local watcher = self.watchers[stream_id]
    if not watcher then
        return false, "watcher not found"
    end
    self.socket:send_rst_stream(stream_id)
    self.watchers[stream_id] = nil
    self.watcher_idxs[key] = nil
    return true
end

function Etcd:check_grpc_status(ok, status, rheaders)
    if ok and status == 200 then
        local grpc_status = rheaders and tonumber(rheaders["grpc-status"])
        if not grpc_status or grpc_status == 0 then
            return true
        end
        return false, sformat("grpc status: %s", grpc_status or "unknown")
    end
    return false, ok and sformat("http status: %s", status) or status
end

function Etcd:send_packet(path, rpc, datas, noheader)
    local headers = {
        ["x-grpc-input"] = rpc.input_type,
        ["x-grpc-output"] = rpc.output_type,
        ["Content-Type"] = "application/grpc",
    }
    local ok, status, body, rheaders, stream_id = self.socket:send_packet(path, rpc.method, headers, datas)
    local gok, err = self:check_grpc_status(ok, status, rheaders)
    if gok then
        if noheader then
            body.header = nil
        end
        return true, body, stream_id
    end
    return false, err
end

function Etcd:__static()
    local interfaces = {
        get         = { "etcdserverpb.KV", "Range", true },
        put         = { "etcdserverpb.KV", "Put", true },
        compact     = { "etcdserverpb.KV", "Compact", true },
        delete      = { "etcdserverpb.KV", "DeleteRange", true },
        watch_req   = { "etcdserverpb.Watch", "Watch", false },
        lease       = { "etcdserverpb.Lease", "LeaseGrant", true },
        revoke      = { "etcdserverpb.Lease", "LeaseRevoke", true },
        keepalive   = { "etcdserverpb.Lease", "LeaseKeepAlive", true },
        ttl         = { "etcdserverpb.Lease", "LeaseTimeToLive", true },
        leases      = { "etcdserverpb.Lease", "LeaseLeases", true },
    }
    for func, info in pairs(interfaces) do
        local service, method, noheader = tunpack(info)
        local path = sformat("/%s/%s", service, method)
        Etcd[func] = function(this, req)
            local rpc = protobuf_mgr:get_service(service, method)
            if rpc then
                return this:send_packet(path, rpc, req, noheader)
            end
            return false, "etcd service not found"
        end
    end
end

return Etcd
