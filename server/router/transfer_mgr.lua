--transfer_mgr.lua

local log_info          = logger.info
local qfailed           = quanta.failed
local name2sid          = service.name2sid
local sid2name          = service.sid2name

local event_mgr         = quanta.get("event_mgr")
local thread_mgr        = quanta.get("thread_mgr")
local router_server     = quanta.get("router_server")

local NODE_ID           = quanta.id
local SUCCESS           = quanta.enum("KernCode", "SUCCESS")
local RPC_FAILED        = quanta.enum("KernCode", "RPC_FAILED")
local PLAYER_NOT_EXIST  = quanta.enum("KernCode", "PLAYER_NOT_EXIST")

local SERVICE_MAX       = 255
local SERVICE_CACHE     = name2sid("cache")

local TransferMgr = singleton()
local prop = property(TransferMgr)
prop:reader("rpc_server", nil)
prop:reader("routers", {})

function TransferMgr:__init()
    --注册事件
    event_mgr:add_listener(self, "rpc_query_lobby")
    event_mgr:add_listener(self, "rpc_query_service")
    event_mgr:add_listener(self, "rpc_router_clean")
    event_mgr:add_listener(self, "rpc_login_service")
    --消息转发
    event_mgr:add_listener(self, "on_transfor_rpc")
    --初始化变量
    self.rpc_server = router_server:get_rpc_server()
end

--rpc协议处理
------------------------------------------------------------------------------
--踢出玩家
function TransferMgr:rpc_router_clean(client, player_id)
    log_info("[TransferMgr][rpc_router_clean] player_id : %s", player_id)
    self.routers[player_id] = nil
    return SUCCESS
end

--角色登录服务
function TransferMgr:rpc_login_service(client, player_id, serv_name, serv_id)
    if self:update_service(player_id, serv_name, serv_id) then
        log_info("[TransferMgr][rpc_login_service]: %s, service: %s-%s", player_id, serv_name, serv_id)
        return SUCCESS
    end
    return RPC_FAILED
end

--获取玩家所在的lobby
function TransferMgr:rpc_query_lobby(client, player_id)
    return self:query_service(player_id, "lobby")
end

--获取玩家所在的服务
function TransferMgr:rpc_query_service(client, player_id, serv_name)
    return self:query_service(player_id, serv_name)
end

function TransferMgr:update_service(pla_id, serv_name, serv_id)
    local router_id = NODE_ID
    local sess_id = thread_mgr:build_session_id()
    if serv_name == "lobby" and serv_id == 0 then
        router_id = 0
    end
    local old_serv_id
    if self.routers[pla_id] then
        old_serv_id = self.routers[pla_id][serv_name]
        self.routers[pla_id][serv_name] = serv_id
    else
        self.routers[pla_id] = {[serv_name] = serv_id}
    end
    local ok, code, routers = self.rpc_server:forward_hash(sess_id, SERVICE_CACHE, pla_id, "rpc_router_update", pla_id, router_id, serv_name, serv_id)
    if qfailed(code, ok) then
        self.routers[pla_id][serv_name] = old_serv_id
        return
    end
    self.routers[pla_id] = routers
    return routers
end

function TransferMgr:query_service(player_id, serv_name)
    local routers = self.routers[player_id]
    if routers then
        return SUCCESS, routers[serv_name]
    end
    local sess_id = thread_mgr:build_session_id()
    local ok, code, rrouters = self.rpc_server:forward_hash(sess_id, SERVICE_CACHE, player_id, "rpc_router_update", player_id, NODE_ID)
    if qfailed(code, ok) then
        return RPC_FAILED
    end
    self.routers[player_id] = rrouters
    return SUCCESS, rrouters[serv_name]
end

--转发消息
function TransferMgr:on_transfor_rpc(client, session_id, service_id, player_id, slice)
    if service_id == SERVICE_MAX then
        self:boardcast_transfor(client, player_id, slice)
        return
    end
    local _, server_id = self:query_service(player_id, sid2name(service_id))
    if not server_id or server_id == 0 then
        if session_id > 0 then
            self.rpc_server:callback(client, session_id, false, PLAYER_NOT_EXIST)
        end
        return
    end
    self.rpc_server:forward_call(session_id, server_id, slice)
end

--转发广播
function TransferMgr:boardcast_transfor(client, player_id, slice)
    local routers = self.routers[player_id]
    if not routers then
        routers = self:update_service(player_id)
    end
    for _, server_id in pairs(routers) do
        if client.id ~= server_id then
            self.rpc_server:forward_call(0, server_id, slice)
        end
    end
end

-- export
quanta.transfer_mgr = TransferMgr()

return TransferMgr
