--online_mgr.lua

--本模块维护了所有在线玩家的索引,即: player_id --> playersvr-id
--当然,不在线的玩家查询结果就是nil:)
--这里维护的在线状态仅供一般性消息中转用,登录状态判定以数据库中记录为准
local pairs             = pairs
local log_info          = logger.info

local monitor           = quanta.get("monitor")
local event_mgr         = quanta.get("event_mgr")
local router_mgr        = quanta.get("router_mgr")

local SUCCESS           = quanta.enum("KernCode", "SUCCESS")
local RPC_FAILED        = quanta.enum("KernCode", "RPC_FAILED")
local PLAYER_NOT_EXIST  = quanta.enum("KernCode", "PLAYER_NOT_EXIST")

local OnlineMgr = singleton()
function OnlineMgr:__init()
    self.players = {}           --在线玩家
    self.lobby_indexs = {}      --lobby玩家索引

    --注册事件
    event_mgr:add_listener(self, "rpc_login_player")
    event_mgr:add_listener(self, "rpc_logout_player")
    event_mgr:add_listener(self, "rpc_query_lobby")
    event_mgr:add_listener(self, "rpc_query_service")
    --消息转发
    event_mgr:add_listener(self, "rpc_call_lobby")
    event_mgr:add_listener(self, "rpc_send_lobby")
    event_mgr:add_listener(self, "rpc_call_service")
    event_mgr:add_listener(self, "rpc_send_service")
    event_mgr:add_listener(self, "rpc_call_client")
    event_mgr:add_listener(self, "rpc_send_client")
    --服务发现
    monitor:watch_service_close(self, "lobby")
end

--rpc协议处理
------------------------------------------------------------------------------
--lobby失活时,所有online清除对应的索引数据
function OnlineMgr:on_service_close(id, service_name)
    if service_name == "lobby" then
        local lobby_data = self.lobby_indexs[id]
        for player_id in pairs(lobby_data or {}) do
            self.players[player_id] = nil
        end
        self.lobby_indexs[id] = {}
    end
end

--角色登陆
function OnlineMgr:rpc_login_player(player_id, gateway, data)
    local lobby = data.lobby
    log_info("[OnlineMgr][rpc_login_player]: %s, lobby: %s, gateway: %s", player_id, lobby, gateway)
    data.gateway = gateway
    self.players[player_id] = data
    if not self.lobby_indexs[lobby] then
        self.lobby_indexs[lobby] = {}
    end
    self.lobby_indexs[lobby][player_id] = true
    return SUCCESS
end

--角色登出
function OnlineMgr:rpc_logout_player(player_id)
    log_info("[OnlineMgr][rpc_logout_player]: %s", player_id)
    local pdata = self.players[player_id]
    if pdata then
        self.players[player_id] = nil
        self.lobby_indexs[pdata.lobby][player_id] = nil
    end
    return SUCCESS
end

--获取玩家所在的lobby
function OnlineMgr:rpc_query_lobby(player_id)
    local pdata = self.players[player_id]
    if not pdata then
        return SUCCESS, 0
    end
    return SUCCESS, pdata.lobby
end

--获取玩家所在的服务
function OnlineMgr:rpc_query_service(player_id, serv_name)
    local pdata = self.players[player_id]
    if not pdata then
        return SUCCESS, 0
    end
    return SUCCESS, pdata[serv_name]
end

-------------------------------------------------------------------
--根据玩家所在的lobby转发消息
function OnlineMgr:rpc_call_lobby(player_id, rpc, ...)
    local pdata = self.players[player_id]
    if not pdata then
        return PLAYER_NOT_EXIST, "player not online!"
    end
    local ok, codeoe, res = router_mgr:call_target(pdata.lobby, rpc, ...)
    if not ok then
        return RPC_FAILED, codeoe
    end
    return codeoe, res
end

--根据玩家所在的lobby转发消息
function OnlineMgr:rpc_send_lobby(player_id, rpc, ...)
    local pdata = self.players[player_id]
    if pdata then
        router_mgr:send_target(pdata.lobby, rpc, ...)
    end
end

--根据玩家所在的服务转发消息
function OnlineMgr:rpc_call_service(player_id, rpc, serv_name, ...)
    local pdata = self.players[player_id]
    if not pdata or not pdata[serv_name] then
        return PLAYER_NOT_EXIST, "player not online!"
    end
    local ok, codeoe, res = router_mgr:call_target(pdata[serv_name], rpc, ...)
    if not ok then
        return RPC_FAILED, codeoe
    end
    return codeoe, res
end

--根据玩家所在的服务转发消息
function OnlineMgr:rpc_send_service(player_id, rpc, serv_name, ...)
    local pdata = self.players[player_id]
    if pdata and pdata[serv_name] then
        router_mgr:send_target(pdata[serv_name], rpc, ...)
    end
end

--组发消息给指定服务的玩家
function OnlineMgr:rpc_group_send_service(player_ids, rpc, serv_name, ...)
    for _, player_id in pairs(player_ids) do
        self:rpc_send_service(player_id, rpc, serv_name, ...)
    end
end

--根据玩家所在的gateway转发消息，然后转发给客户端
function OnlineMgr:rpc_call_client(player_id, ...)
    local pdata = self.players[player_id]
    if not pdata then
        return PLAYER_NOT_EXIST, "player not online!"
    end
    local ok, codeoe, res = router_mgr:call_target(pdata.gateway, "rpc_forward_client", player_id, ...)
    if not ok then
        return RPC_FAILED, codeoe
    end
    return codeoe, res
end

--根据玩家所在的gateway转发消息，然后转发给客户端
function OnlineMgr:rpc_send_client(player_id, ...)
    local pdata = self.players[player_id]
    if pdata then
        router_mgr:send_target(pdata.gateway, "rpc_forward_client", player_id, ...)
    end
end

-- export
quanta.online_mgr = OnlineMgr()

return OnlineMgr
