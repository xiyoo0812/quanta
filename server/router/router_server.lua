--router_server.lua
local lcodec        = require("lcodec")

local log_err       = logger.err
local log_info      = logger.info
local signalquit    = signal.quit
local sformat       = string.format
local hash_code     = lcodec.hash_code
local lencode       = lcodec.encode_slice

local socket_mgr    = quanta.get("socket_mgr")
local config_mgr    = quanta.get("config_mgr")
local thread_mgr    = quanta.get("thread_mgr")

local RpcServer     = import("network/rpc_server.lua")

local FLAG_RES      = quanta.enum("FlagMask", "RES")
local SUCCESS       = quanta.enum("KernCode", "SUCCESS")
local UNREACHABLE   = quanta.enum("KernCode", "RPC_UNREACHABLE")

local RouterServer = singleton()
local prop = property(RouterServer)
prop:reader("rpc_server", nil)
prop:reader("service_masters", {})

function RouterServer:__init()
    local host = quanta.host
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
    self.rpc_server = RpcServer(self, "0.0.0.0", config.port, true)

    --因为按host简化配置，可以重复index, 需要重定义routerid
    quanta.name = sformat("router_%s-%s", host, index)
    quanta.id = service.make_sid(hash_code(host, 65536), index)
    service.make_node(self.rpc_server:get_port())
end

--其他服务器节点关闭
function RouterServer:on_client_error(client, client_token, err)
    log_info("[RouterServer][on_client_error] %s lost: %s", client.name, err)
    socket_mgr.map_token(client.id)
    local service = client.service
    if client.id == self.service_masters[service] then
        local new_master = nil
        for _, eclient in self.rpc_server:iterator() do
            if not new_master or eclient.id < new_master.id then
                new_master = eclient
            end
        end
        if new_master then
            socket_mgr.set_master(service, new_master.id)
            self.service_masters[service] = new_master.id
            log_info("[RouterServer][on_socket_error] switch master --> %s", new_master.name)
        end
    end
end

--accept事件
function RouterServer:on_client_accept(client)
    log_info("[RouterServer][on_client_accept] new connection, token=%s", client.token)
    client.on_forward_error = function(session_id)
        thread_mgr:fork(function()
            log_err("[RouterServer][on_client_accept] on_forward_error, session_id=%s", session_id)
            local slice = lencode(false, UNREACHABLE, "router con't find target!")
            client.call(session_id, FLAG_RES, slice)
        end)
    end
    client.on_forward_broadcast = function(session_id, broadcast_num)
        thread_mgr:fork(function()
            local slice = lencode(true, SUCCESS, broadcast_num)
            client.call(session_id, FLAG_RES, slice)
        end)
    end
end

--rpc事件处理
------------------------------------------------------------------
--注册服务器
function RouterServer:on_client_register(client, node, client_id)
    log_info("[RouterServer][on_client_register] service: %s", client.name)
    local service = client.service
    local old_master = self.service_masters[service]
    socket_mgr.map_token(client_id, client.token)
    if not old_master or client_id < old_master then
        socket_mgr.set_master(service, client_id)
        self.service_masters[service] = client_id
        log_info("[RouterServer][on_socket_error] switch master --> %s", client.name)
    end
end

-- 会话信息
function RouterServer:on_client_beat(client)
end

quanta.router_server = RouterServer()

return RouterServer
