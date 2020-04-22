--node_mgr.lua
local pairs         = pairs
local xpcall        = xpcall
local mhuge         = math.huge
local log_err       = logger.err
local log_info      = logger.info
local log_warn      = logger.warn
local env_addr      = environ.addr
local sid2name      = service.id2name
local sget_group    = service.get_group
local smake_id      = service.make_id
local services      = service.groups
local hxpcall       = quanta.xpcall

local socket_mgr    = quanta.socket_mgr

local SERVICE_TIMEOUT   = 10000
local RPC_FAILED        = err.Code.RPC_FAILED

local ServerMgr = singleton()
function ServerMgr:__init()
    self.group_masters =  {}
    self.servers =  {}
    self.listener = nil

    self.kick_servers = {}

    --初始化
    self:setup()
end

--初始化
function ServerMgr:setup()
    local options = quanta.options
    local ip, port = env_addr("ENV_ROUTER_LISTEN_ADDR")
    self.listener = socket_mgr.listen(ip, port)
    if not self.listener then
        log_info("routor now listen %s:%s failed", ip, port)
        os.exit(1)
    end
    log_info("routor now listen %s:%s success!", ip, port)
    quanta.id = smake_id(services.router, options.index)
    self.listener.on_accept = function(server)
        hxpcall(self.on_server_accept, "on_server_accept: %s", self, server)
    end
end

--rpc事件
function ServerMgr:server_rpc(server, rpc, ...)
    server.alive_time = quanta.now
    if not rpc then
        log_err("nil s2s rpc !")
    return
    end
    local proc = self[rpc]
    if not proc then
        log_err("undefined s2s rpc: %s", rpc)
        return
    end
    local ok, err = xpcall(proc, debug.traceback, self, server, ...)
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
        log_warn(format, server_token,  sid2name(kick_server_id), self.servers[server_token].ip)
        self.kick_servers[server_token] = nil
        self.servers[server_token] = nil
        return
    end
    self.servers[server_token] = nil
    local server_id = server.id
    local server_group = server.group
    if not server_id or not server_group then
        return
    end
    --要实现固定哈希的话,可以把这里的nil改为0
    socket_mgr.map_token(server_id, nil)
    local is_master = (server_id == self.group_masters[server_group])
    if is_master then
        self.group_masters[server_group] = nil
        socket_mgr.set_master(server_group, 0)
    end
    local router_id = quanta.id
    local new_master, new_master_token = mhuge, nil
    --通知其他服务器
    for exist_token, exist_server in pairs(self.servers) do
        exist_server.call_lua("on_server_close", server_id, router_id)
        if is_master and exist_server.group == server_group and exist_server.id < new_master then
            new_master = exist_server.id
            new_master_token = exist_token
        end
    end
    --switch master
    if is_master and new_master_token then
        self.group_masters[server_group] = new_master
        socket_mgr.set_master(server_group, new_master_token)
        log_info("[ServerMgr][on_server_close] switch master --> %s", sid2name(new_master))
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
        local server_name = sid2name(id)
        local server_group = sget_group(id)
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
        server.group = server_group
        socket_mgr.map_token(id, server_token)
        log_info("[ServerMgr][register] service: %s", server.name)
        --switch master
        local group_master = self.group_masters[server_group] or mhuge
        if id < group_master then
            self.group_masters[server_group] = id
            socket_mgr.set_master(server_group, server_token)
            log_info("[ServerMgr][register] switch master --> %s", server_name)
        end
        --通知其他服务器
        local router_id = quanta.id
        for _, exist_server in pairs(self.servers) do
            local exist_server_id = exist_server.id
            if exist_server_id and exist_server_id ~= id then
                exist_server.call_lua("on_server_register", id, server_group, router_id)
                server.call_lua("on_server_register", exist_server_id, exist_server.group, router_id)
            end
        end
    end
end

--服务器心跳协议
function ServerMgr:heartbeat(server)
    server.call_lua("on_heartbeat", quanta.id)
end

quanta.node_mgr = ServerMgr()

return ServerMgr
