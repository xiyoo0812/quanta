--login_mgr.lua
local trandom       = qtable.random
local log_debug     = logger.debug

local discover      = quanta.get("discover")
local event_mgr     = quanta.get("event_mgr")
local protobuf_mgr  = quanta.get("protobuf_mgr")

local Deque         = import("container/deque.lua")

local LoginMgr = singleton()
local prop = property(LoginMgr)
prop:reader("services", {})

function LoginMgr:__init()
    -- 网络事件监听
    event_mgr:add_listener(self, "on_socket_error")
    event_mgr:add_listener(self, "on_socket_accept")
    -- cs协议监听
    protobuf_mgr:register(self, "NID_HEARTBEAT_REQ", "on_heartbeat_req")
end

--观察服务
function LoginMgr:watch_service(serv_name)
    discover:watch_service(self, serv_name)
end

function LoginMgr:on_service_close(id, name, info)
    log_debug("[LoginMgr][on_service_close] node: {}-{}", name, id)
    local region = self.services[name][info.region]
    region:remove_by_index(info.id)
end

function LoginMgr:on_service_ready(id, name, info)
    log_debug("[LoginMgr][on_service_ready] node: {}-{}, info: {}", name, id, info)
    local services = self.services[name]
    if not services then
        self.services[name] = {}
        services = self.services[name]
    end
    local region = services[info.region]
    if not region then
        region = Deque("id")
        services[info.region] = region
    end
    region:push_back(info)
end

function LoginMgr:find_server(serv_name, region)
    local services = self.services[serv_name]
    if not services then
        return
    end
    local sregion = services[region]
    if not sregion or sregion:empty() then
        return
    end
    local regions = sregion:get_indexs()
    local id, info = trandom(regions)
    return id, info.host, info.port
end

--心跳协议
function LoginMgr:on_heartbeat_req(session, message, body, response)
    response.time = quanta.now_ms
    response.serial = body.serial + 1
end

--客户端连上
function LoginMgr:on_socket_accept(session)
    log_debug("[LoginMgr][on_socket_accept] {} connected!", session.token)
end

--客户端连接断开
function LoginMgr:on_socket_error(session, token, err)
    local account = session.account
    if account then
        log_debug("[LoginMgr][on_socket_error] (t:{}-o:{}-u:{}) lost, because: {}!", token, account.open_id, account.user_id, err)
    end
end

quanta.login_mgr = LoginMgr()

return LoginMgr
