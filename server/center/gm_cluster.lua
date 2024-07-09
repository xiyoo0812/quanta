--gm_cluster.lua
import("center/gm_mgr.lua")
import("agent/online_agent.lua")

local log_err           = logger.err
local make_sid          = service.make_sid
local guid_index        = codec.guid_index

local online            = quanta.get("online")
local gm_mgr            = quanta.get("gm_mgr")
local router_mgr        = quanta.get("router_mgr")

local GLOBAL            = quanta.enum("GMType", "GLOBAL")
local SYSTEM            = quanta.enum("GMType", "SYSTEM")
local SERVICE           = quanta.enum("GMType", "SERVICE")
local HASHKEY           = quanta.enum("GMType", "HASHKEY")
local PLAYER            = quanta.enum("GMType", "PLAYER")

local GM_Cluster = singleton()

function GM_Cluster:__init()
    --注册GM Handler
    gm_mgr:register_handler(GLOBAL, self, "exec_global_cmd")
    gm_mgr:register_handler(SYSTEM, self, "exec_system_cmd")
    gm_mgr:register_handler(PLAYER, self, "exec_player_cmd")
    gm_mgr:register_handler(HASHKEY, self, "exec_hashkey_cmd")
    gm_mgr:register_handler(SERVICE, self, "exec_service_cmd")
end

-------------------------------------------------------------------------
--GLOBAL command
function GM_Cluster:exec_global_cmd(service_id, cmd_name, ...)
    local ok, codeoe, res = router_mgr:call_master(service_id, "rpc_command_execute" , cmd_name, ...)
    if not ok then
        log_err("[GM_Cluster][exec_global_cmd] rpc_command_execute failed! service_id:{},cmd_name={},code={},res={}", service_id, cmd_name, codeoe, res)
        return { code = 1, msg = codeoe }
    end
    return { code = codeoe, msg = res }
end

--system command
function GM_Cluster:exec_system_cmd(service_id, cmd_name, target_id, ...)
    local index = guid_index(target_id)
    local quanta_id = make_sid(service_id, index)
    local ok, codeoe, res = router_mgr:call_target(quanta_id, "rpc_command_execute" , cmd_name, target_id, ...)
    if not ok then
        log_err("[GM_Cluster][exec_system_cmd] rpc_command_execute failed! cmd_name={},code={},res={}", cmd_name, codeoe, res)
        return { code = 1, msg = codeoe }
    end
    return { code = codeoe, msg = res }
end

--service command
function GM_Cluster:exec_service_cmd(service_id, cmd_name, ...)
    local ok, codeoe = router_mgr:broadcast(service_id, "rpc_command_execute" , cmd_name, ...)
    if not ok then
        log_err("[GM_Cluster][exec_service_cmd] rpc_command_execute failed! cmd_name={}", cmd_name)
        return { code = 1, msg = codeoe }
    end
    return { code = codeoe, msg = "success" }
end

--hash command
function GM_Cluster:exec_hashkey_cmd(service_id, cmd_name, target_id, ...)
    local ok, codeoe, res = router_mgr:call_hash(service_id, target_id, "rpc_command_execute", cmd_name, target_id, ...)
    if not ok then
        log_err("[GM_Cluster][exec_hashkey_cmd] rpc_command_execute failed! cmd_name={}", cmd_name)
        return { code = 1, msg = codeoe }
    end
    return { code = codeoe, msg = res }
end

--player command
function GM_Cluster:exec_player_cmd(service_id, cmd_name, player_id, ...)
    if player_id == 0 then
        local ok, codeoe, res = router_mgr:call_lobby_random("rpc_command_execute", cmd_name, player_id, ...)
        if not ok then
            log_err("[GM_Cluster][exec_player_cmd] rpc_command_execute failed! cmd_name={} player_id={}", cmd_name, player_id)
            return { code = 1, msg = codeoe }
        end
        return { code = codeoe, msg = res }
    end
    local ok, codeoe, res = online:call_service(player_id, "rpc_command_execute", "lobby", cmd_name, player_id, ...)
    if not ok then
        log_err("[GM_Cluster][exec_player_cmd] rpc_command_execute failed! cmd_name={} player_id={}", cmd_name, player_id)
        return { code = 1, msg = codeoe }
    end
    return { code = codeoe, msg = res }
end

quanta.gm_Cluster = GM_Cluster()

return GM_Cluster