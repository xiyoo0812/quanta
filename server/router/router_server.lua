--router_server.lua

local mhuge         = math.huge
local log_err       = logger.err
local log_info      = logger.info
local log_warn      = logger.warn
local util_addr     = utility.addr
local sid2sid       = service.id2sid
local sid2nick      = service.id2nick
local sid2name      = service.id2name

local KernCode      = enum("KernCode")
local RpcServer     = import("kernel/network/rpc_server.lua")

local event_mgr     = quanta.get("event_mgr")
local socket_mgr    = quanta.get("socket_mgr")
local config_mgr    = quanta.get("config_mgr")

local RouterServer = singleton()
local prop = property(RouterServer)
prop:accessor("rpc_server", nil)
prop:accessor("kick_servers", {})
prop:accessor("service_masters", {})
function RouterServer:__init()
    self:setup()
end

function RouterServer:setup()
    local router_db = config_mgr:get_table("router")
    local router_conf = router_db:find_one(quanta.index)
    if not router_conf then
        log_err("[RouterServer][setup] router_conf is nil index:%s", quanta.index)
        os.exit(1)
    end
    local ip, port = util_addr(router_conf.addr)
    self.rpc_server = RpcServer()
    self.rpc_server:setup(ip, port)
    --监听事件
    event_mgr:add_listener(self, "on_socket_close")
    event_mgr:add_listener(self, "on_socket_accept")
    event_mgr:add_listener(self, "rpc_service_register")
end

--其他服务器节点关闭
function RouterServer:on_socket_close(server, server_token, err)
    log_info("[RouterServer][on_socket_close] %s lost: %s", server.name or server_token, err)
    local kick_server_id = self.kick_servers[server_token]
    if kick_server_id then
        local format = "[RouterServer][on_socket_close] kick server close! token:%s, name:%s, ip:%s"
        log_warn(format, server_token,  server.name, server.ip)
        self.kick_servers[server_token] = nil
        return
    end
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
    for exist_token, exist_server in self.rpc_server:iterator() do
        self.rpc_server:send(exist_server, "rpc_service_close", server_id, router_id)
        if is_master and exist_server.service_id == service_id and exist_server.id < new_master then
            new_master = exist_server.id
            new_master_token = exist_token
        end
    end
    --switch master
    if is_master and new_master_token then
        self.service_masters[service_id] = new_master
        socket_mgr.set_master(service_id, new_master_token)
        log_info("[RouterServer][on_socket_close] switch master --> %s", sid2nick(new_master))
    end
end

--accept事件
function RouterServer:on_socket_accept(server)
    --log_info("[RouterServer][on_socket_accept] new connection, token=%s", server.token)
    server.on_router_error = function(session_id, rpc_flag, source)
        log_info("[RouterServer][on_router_error] on_router_error, session_id=%s", session_id)
        server.call(session_id, 1, quanta.id, "on_router_error", false, KernCode.RPC_FAILED, "router con't find target!")
    end
end

--rpc事件处理
------------------------------------------------------------------
--注册服务器
function RouterServer:rpc_service_register(server, id)
    if not server.id then
        local service_id = sid2sid(id)
        local server_name = sid2nick(id)
        local servive_name = sid2name(id)
        local server_token = server.token
        -- 检查是否顶号
        for exist_token, exist_server in self.rpc_server:iterator() do
            if exist_server.id == id then
                self.kick_servers[exist_token] = id
                self.rpc_server:send(exist_server, "rpc_service_kickout", quanta.id, exist_server.ip)
                break
            end
        end
        server.id = id
        server.name = server_name
        server.service_id = service_id
        server.servive_name = servive_name
        socket_mgr.map_token(id, server_token)
        log_info("[RouterServer][rpc_service_register] service: %s", server_name)
        --switch master
        local group_master = self.service_masters[service_id] or mhuge
        if id < group_master then
            self.service_masters[service_id] = id
            socket_mgr.set_master(service_id, server_token)
            log_info("[RouterServer][rpc_service_register] switch master --> %s", server_name)
        end
        --通知其他服务器
        local router_id = quanta.id
        for _, exist_server in self.rpc_server:iterator() do
            local exist_server_id = exist_server.id
            if exist_server_id and exist_server_id ~= id then
                self.rpc_server:send(exist_server, "rpc_service_ready", id, servive_name, router_id)
                self.rpc_server:send(server, "rpc_service_ready", exist_server_id, exist_server.servive_name, router_id)
            end
        end
    end
end

quanta.router_server = RouterServer()

return RouterServer
