--router_server.lua
local log_err       = logger.err
local log_info      = logger.info
local signalquit    = signal.quit
local env_get       = environ.get
local sformat       = string.format
local qhash_code    = quanta.hash_code

local socket_mgr    = quanta.get("socket_mgr")
local config_mgr    = quanta.get("config_mgr")

local RpcServer     = import("network/rpc_server.lua")

local FLAG_RES      = quanta.enum("FlagMask", "RES")
local SUCCESS       = quanta.enum("KernCode", "SUCCESS")
local UNREACHABLE   = quanta.enum("KernCode", "RPC_UNREACHABLE")

local RouterServer = singleton()
local prop = property(RouterServer)
prop:accessor("rpc_server", nil)
prop:accessor("service_masters", {})

function RouterServer:__init()
    local host = env_get("QUANTA_HOST_IP")
    local router = config_mgr:init_table("router", "host")
    local config = router:find_one(host)
    if not config then
        log_err("[RouterServer][setup] config is nil, host:%s", host)
        signalquit()
        return
    end
    local index = quanta.index
    if index > config.count then
        log_err("[RouterServer][setup] index(%s) outof range, host:%s", index, host)
        signalquit()
        return
    end
    --启动server
    self.rpc_server = RpcServer(self, host, config.port, true)

    --因为按host简化配置，可以重复index, 需要重定义routerid
    quanta.name = sformat("router_%s-%s", host, index)
    quanta.id = service.make_sid(qhash_code(host, 65536), index)
    service.make_node(self.rpc_server:get_port())
end

--其他服务器节点关闭
function RouterServer:on_client_error(client, client_token, err)
    log_info("[RouterServer][on_client_error] %s lost: %s", client.name, err)
    socket_mgr.map_token(client.id)
end

--accept事件
function RouterServer:on_client_accept(client)
    log_info("[RouterServer][on_client_accept] new connection, token=%s", client.token)
    client.on_forward_error = function(session_id)
        log_err("[RouterServer][on_client_accept] on_forward_error, session_id=%s", session_id)
        client.call(session_id, FLAG_RES, quanta.id, "on_forward_error", false, UNREACHABLE, "router con't find target!")
    end
    client.on_forward_broadcast = function(session_id, broadcast_num)
        client.call(session_id, FLAG_RES, quanta.id, "on_forward_broadcast", true, SUCCESS, broadcast_num)
    end
end

--rpc事件处理
------------------------------------------------------------------
--注册服务器
function RouterServer:on_client_register(client, node)
    socket_mgr.map_token(client.id, client.token)
    log_info("[RouterServer][on_client_register] service: %s", client.name)
end

-- 会话信息
function RouterServer:on_client_beat(client)
end

quanta.router_server = RouterServer()

return RouterServer
