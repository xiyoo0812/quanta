--router_server.lua
local lcodec        = require("lcodec")

local log_err       = logger.err
local log_info      = logger.info
local lencode       = lcodec.encode_slice

local socket_mgr    = quanta.get("socket_mgr")
local thread_mgr    = quanta.get("thread_mgr")

local RpcServer     = import("network/rpc_server.lua")

local FLAG_RES      = quanta.enum("FlagMask", "RES")
local SUCCESS       = quanta.enum("KernCode", "SUCCESS")
local UNREACHABLE   = quanta.enum("KernCode", "RPC_UNREACHABLE")

local RouterServer = singleton()
local prop = property(RouterServer)
prop:reader("rpc_server", nil)

function RouterServer:__init()
    local inner = environ.get("QUANTA_INNER_IP")
    local ip, port = environ.addr("QUANTA_ROUTER_ADDR")
    local rserver = RpcServer(self, ip, port, true)
    service.make_node(rserver:get_port(), inner)
    self.rpc_server = rserver
end

--其他服务器节点关闭
function RouterServer:on_client_error(client, client_token, err)
    log_info("[RouterServer][on_client_error] %s lost: %s", client.name, err)
    local new_master = socket_mgr.map_token(client.id)
    log_info("[RouterServer][on_socket_error] %s master --> %s", client.service_name, new_master)
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
    local new_master = socket_mgr.map_token(client_id, client.token)
    log_info("[RouterServer][on_client_register] %s master --> %s", client.service_name, new_master)
end

-- 会话信息
function RouterServer:on_client_beat(client)
end

quanta.router_server = RouterServer()

return RouterServer
