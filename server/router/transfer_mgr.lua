--transfer_mgr.lua

local log_info          = logger.info
local log_warn          = logger.warn
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
    event_mgr:add_listener(self, "on_transfer_rpc")
    event_mgr:add_listener(self, "on_broadcast_rpc")
    --初始化变量
    self.rpc_server = router_server:get_rpc_server()
end

--rpc协议处理
------------------------------------------------------------------------------
--踢出玩家
function TransferMgr:rpc_router_clean(client, player_id)
    if self.routers[player_id] then
        log_info("[TransferMgr][rpc_router_clean] player_id : {}", player_id)
        self.routers[player_id] = nil
    end
    return SUCCESS
end

--角色登录服务
function TransferMgr:rpc_login_service(client, player_id, serv_name, serv_id)
    local routers = self:update_service(player_id, serv_name, serv_id)
    if routers then
        log_info("[TransferMgr][rpc_login_service]: {}, service: {}-{}", player_id, serv_name, serv_id)
        return SUCCESS
    end
    log_warn("[TransferMgr][rpc_login_service]: {}, service: {}-{} failed!", player_id, serv_name, serv_id)
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

--转发广播
function TransferMgr:on_broadcast_rpc(client, player_id, slice)
    local routers = self:find_routers(player_id)
    if not routers then
        slice = slice.string()
        routers = self:query_routers(player_id, NODE_ID)
    end
    if not routers then
        log_warn("[TransferMgr][on_broadcast_rpc]: {} find routers failed!", player_id)
        return
    end
    for _, server_id in pairs(routers) do
        if client.id ~= server_id then
            self.rpc_server:transfer_call(0, server_id, slice)
        end
    end
end

--转发消息
function TransferMgr:on_transfer_rpc(client, session_id, service_id, player_id, slice)
    local serv_name = sid2name(service_id)
    local routers = self:find_routers(player_id)
    if not routers then
        slice = slice.string()
        routers = self:query_routers(player_id, NODE_ID)
    end
    if not routers or not routers[serv_name] or routers[serv_name] == 0 then
        if session_id > 0 then
            self.rpc_server:callback(client, session_id, false, PLAYER_NOT_EXIST)
        end
        log_warn("[TransferMgr][on_transfer_rpc]: {}, service: {} failed!", player_id, serv_name)
        return
    end
    self.rpc_server:transfer_call(session_id, routers[serv_name], slice)
end

--本地函数
-----------------------------------------------------------------
function TransferMgr:update_service(pla_id, serv_name, serv_id)
    local old_serv_id
    local orouters = self.routers[pla_id]
    if orouters then
        old_serv_id = orouters[serv_name]
        orouters[serv_name] = serv_id
    else
        self.routers[pla_id] = {[serv_name] = serv_id}
    end
    if old_serv_id == serv_id then
        return orouters
    end
    local router_id = NODE_ID
    if serv_name == "lobby" and serv_id == 0 then
        router_id = 0
    end
    local routers = self:query_routers(pla_id, router_id, serv_name, serv_id)
    if not routers then
        self.routers[pla_id][serv_name] = old_serv_id
        log_warn("[TransferMgr][update_service]: {} service: {} failed!", pla_id, serv_name)
        return
    end
    return routers
end

--查询服务
function TransferMgr:query_service(player_id, serv_name)
    local routers = self.routers[player_id]
    if routers then
        return SUCCESS, routers[serv_name]
    end
    local rrouters = self:query_routers(player_id, NODE_ID)
    if not rrouters then
        log_warn("[TransferMgr][query_service]: {} service: {} failed!", player_id, serv_name)
        return RPC_FAILED
    end
    return SUCCESS, rrouters[serv_name]
end

function TransferMgr:find_routers(player_id)
    return self.routers[player_id]
end

function TransferMgr:query_routers(player_id, router_id, serv_name, serv_id)
    local sess_id = thread_mgr:build_session_id()
    local ok, code, routers = self.rpc_server:transfer_hash(sess_id, SERVICE_CACHE, player_id, "rpc_router_update", player_id, router_id, serv_name, serv_id)
    if qfailed(code, ok) then
        return
    end
    self.routers[player_id] = routers
    return routers
end

-- export
quanta.transfer_mgr = TransferMgr()

return TransferMgr
