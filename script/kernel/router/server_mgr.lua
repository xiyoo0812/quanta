--server_mgr.lua
local pairs         = pairs
local xpcall        = xpcall
local tonumber      = tonumber
local mhuge         = math.huge
local log_err       = logger.err
local log_info      = logger.info
local log_warn      = logger.warn
local env_addr      = environ.addr
local sid2nick      = service.id2nick
local sid2name      = service.id2name
local smake_id      = service.make_id
local sname2sid     = service.name2sid
local services      = service.groups
local hxpcall       = quanta.xpcall

local socket_mgr    = quanta.socket_mgr

local SERVICE_TIMEOUT   = 10000
local RPC_FAILED        = quanta.err_code.RPC_FAILED

local ServerMgr = singleton()
function ServerMgr:__init()
    self.service_masters =  {}
    self.servers =  {}
    self.listener = nil

    self.kick_servers = {}

    --初始化
    self:setup()
end

--初始化
function ServerMgr:setup()
    local ip, port = env_addr("QUANTA_ROUTER_ADDR")
    if not ip or not port then
        log_err("routor QUANTA_ROUTER_ADDR is nil")
        os.exit(1)
    end
    local real_port = tonumber(port) + quanta.index
    self.listener = socket_mgr.listen(ip, real_port)
    if not self.listener then
        log_err("routor now listen %s:%s failed", ip, real_port)
        os.exit(1)
    end
    log_info("routor now listen %s:%s success!", ip, real_port)
    self.listener.on_accept = function(server)
        hxpcall(self.on_server_accept, "on_server_accept: %s", self, server)
    end
end

--rpc事件
function ServerMgr:server_rpc(server, rpc, ...)
    server.alive_time = quanta.now
    local ok, err = xpcall(self.proc, debug.traceback, self, server, ...)
    if not ok then
        log_err("failed to call s2s rpc: %s", rpc)
        log_err(err)
    end
end

--连接关闭
function ServerMgr:on_server_close(server, err)
    local server_token = server.token
    log_err("[ServerMgr][on_server_close] %s lost: %s", server.name or server_token, err)
    local kick_server_id = self.kick_servers[server_token]
    if kick_server_id then
        local format = "[ServerMgr][on_server_close] kick server close! token:%s, kick_server_name:%s, ip:%s"
        log_warn(format, server_token,  sid2nick(kick_server_id), self.servers[server_token].ip)
        self.kick_servers[server_token] = nil
        self.servers[server_token] = nil
        return
    end
    self.servers[server_token] = nil
    local server_id = server.id
    local service_id = server.service_id
    if not server_id or not service_id then
        return
    end
    --要实现固定哈希的话,可以把这里的nil改为0
    socket_mgr.map_token(server_id, nil)
    local is_master = (server_id == self.service_masters[service_id])
    if is_master then
        self.service_masters[service_id] = nil
        socket_mgr.set_master(service_id, 0)
    end
    local router_id = quanta.id
    local new_master, new_master_token = mhuge, nil
    --通知其他服务器
    for exist_token, exist_server in pairs(self.servers) do
        exist_server.call_lua("on_server_close", server_id, router_id)
        if is_master and exist_server.service_id == service_id and exist_server.id < new_master then
            new_master = exist_server.id
            new_master_token = exist_token
        end
    end
    --switch master
    if is_master and new_master_token then
        self.service_masters[service_id] = new_master
        socket_mgr.set_master(service_id, new_master_token)
        log_info("[ServerMgr][on_server_close] switch master --> %s", sid2nick(new_master))
    end
end

--accept事件
function ServerMgr:on_server_accept(server)
    log_info("[ServerMgr][on_server_accept] new connection, token=%s", server.token)
    server.set_timeout(SERVICE_TIMEOUT)
    self.servers[server.token] = server

    server.on_call = function(recv_len, session_id, rpc_type, source, rpc, ...)
        hxpcall(self.server_rpc, "server_rpc: %s", self, server, rpc, ...)
    end
    server.call_lua = function(rpc, ...)
        local send_len = server.call(0, 0, quanta.id, rpc, ...)
        if send_len < 0 then
            log_err("[ServerMgr][call_lua] call failed! code:%s", send_len)
            return false
        end
        return true
    end
    server.on_error = function(err)
        hxpcall(self.on_server_close, "on_server_close: %s", self, server, err)
    end
    server.on_router_error = function(session_id, rpc_type, source)
        log_info("[ServerMgr][on_router_error] on_router_error, session_id=%s", session_id)
        server.call(session_id, 1, quanta.id, "on_router_error", false, RPC_FAILED, "router con't find target!")
    end
end

--rpc事件处理
------------------------------------------------------------------
--注册服务器
function ServerMgr:register(server, id)
    if not server.id then
        local service_id = sid2name(id)
        local server_name = sid2nick(id)
        local server_token = server.token
        -- 检查是否顶号
        for exist_token, exist_server in pairs(self.servers) do
            if exist_server.id == id then
                self.kick_servers[exist_token] = id
                exist_server.call_lua("on_server_kickout", quanta.id, exist_server.ip)
                break
            end
        end
        server.id = id
        server.name = server_name
        server.service_id = service_id
        socket_mgr.map_token(id, server_token)
        log_info("[ServerMgr][register] service: %s", server.name)
        --switch master
        local group_master = self.service_masters[service_id] or mhuge
        if id < group_master then
            self.service_masters[service_id] = id
            socket_mgr.set_master(service_id, server_token)
            log_info("[ServerMgr][register] switch master --> %s", server_name)
        end
        --通知其他服务器
        local router_id = quanta.id
        for _, exist_server in pairs(self.servers) do
            local exist_server_id = exist_server.id
            if exist_server_id and exist_server_id ~= id then
                exist_server.call_lua("on_server_register", id, service_id, router_id)
                server.call_lua("on_server_register", exist_server_id, exist_server.service_id, router_id)
            end
        end
    end
end

--服务器心跳协议
function ServerMgr:heartbeat(server)
    server.call_lua("on_heartbeat", quanta.id)
end

quanta.server_mgr = ServerMgr()

return ServerMgr
