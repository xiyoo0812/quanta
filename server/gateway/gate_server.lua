--gate_server.lua
local log_err       = logger.err
local log_info      = logger.info
local log_warn      = logger.warn
local log_debug     = logger.debug
local sid2name      = service.id2name

local event_mgr     = quanta.get("event_mgr")
local update_mgr    = quanta.get("update_mgr")
local socket_mgr    = quanta.get("socket_mgr")
local client_mgr    = quanta.get("client_mgr")
local protobuf_mgr  = quanta.get("protobuf_mgr")

local SUCCESS       = quanta.enum("KernCode", "SUCCESS")
local MINUTE_5_S    = quanta.enum("PeriodTime", "MINUTE_5_S")

local TOKEN_ERR     = protobuf_mgr:error_code("LOGIN_PLAYER_TOKEN_ERR")
local SERVER_UPHOLD = protobuf_mgr:error_code("LOGIN_SERVER_UPHOLD")
local KICK_CRASH    = protobuf_mgr:enum("kick_reason", "KICK_CRASH")
local KICK_RELOGIN  = protobuf_mgr:enum("kick_reason", "KICK_RELOGIN")

local GateServer = singleton()
local prop = property(GateServer)
prop:reader("clients", {})
prop:reader("servers", {})
prop:reader("verify_codes", {})
prop:accessor("main_service", "lobby")     --主要服务

function GateServer:__init()
    -- 重新设置
    local nport = client_mgr:get_port()
    local domain = environ.get("QUANTA_DOMAIN_ADDR", luabus.host())
    service.modify_host(nport, domain)
    -- 网络事件监听
    event_mgr:add_listener(self, "on_socket_accept")
    event_mgr:add_listener(self, "on_socket_error")
    -- rpc事件监听
    event_mgr:add_listener(self, "rpc_update_verify_code")
    -- cs协议监听
    protobuf_mgr:register(self, "NID_HEARTBEAT_REQ", "on_heartbeat_req")
    protobuf_mgr:register(self, "NID_GATE_BIND_CLIENT_REQ", "on_bind_client_req")
    protobuf_mgr:register(self, "NID_GATE_BIND_SERVER_REQ", "on_bind_server_req")
    protobuf_mgr:register(self, "NID_GATE_BIND_SERVICE_REQ", "on_bind_service_req")
    -- 回调注册
    update_mgr:attach_minute(self)
end

function GateServer:on_minute()
    local now = quanta.now
    for user_id, verify in pairs(self.verify_codes) do
        if not verify.token then
            log_warn("[GateServer][on_minute] user({}) verify_code({}) timeout!", user_id, verify.code)
            self.verify_codes[user_id] = nil
            goto continue
        end
        if now > verify.time then
            local client = client_mgr:get_session(verify.token)
            if not client then
                log_warn("[GateServer][on_minute] user({}) verify_code({}) timeout!", user_id, verify.code)
                self.verify_codes[user_id] = nil
                goto continue
            end
            verify.code = now
            verify.time = now + MINUTE_5_S
            client_mgr:call(client, "NID_GATE_VERIFY_CODE_NTF", { verify_code = now })
        end
        :: continue ::
    end
end

--心跳协议
function GateServer:on_heartbeat_req(session, message, body, response)
    response.time = quanta.now_ms
    response.serial = body.serial + 1
end

function GateServer:on_bind_client_req(session, message, body, response)
    log_debug("[GateServer][on_bind_client_req]) body({}))", body)
    local client_id, verify_code = body.client_id, body.verify_code
    local client = self.clients[client_id]
    if client then
        if client.token ~= session.token then
            log_warn("[GateServer][on_bind_client_req] client({}) rebind! old will be kick!", client_id)
            client_mgr:call(client, "NID_GATE_KICK_CLIENT_NTF", { reason = KICK_RELOGIN })
        end
    end
    local verify = self.verify_codes[client_id]
    if not verify or verify.code ~= verify_code or quanta.now > verify.time then
        log_err("[GateServer][on_bind_client_req] user({}) verify_code({}=>{}) timeout!", client_id, verify_code, verify)
        return message:callback_code(TOKEN_ERR)
    end
    local server_id = body.server_id
    local server = self.servers[server_id]
    if not server then
        log_err("[GateServer][on_bind_client_req] server({}) not exist!", server_id)
        return message:callback_code(SERVER_UPHOLD)
    end
    verify.token = session.token
    session.node_id = client_id
    self.clients[client_id] = session
    socket_mgr.map_client(client_id, session.token)
    socket_mgr.map_server(client_id, server_id, server.token)
    log_info("[GateServer][on_bind_client_req] client({}) bind!", client_id)
end

function GateServer:on_bind_server_req(session, message, body, response)
    log_debug("[GateServer][on_bind_server_req]) body({}))", body)
    local server_id = body.server_id
    local server = self.servers[server_id]
    if server then
        if server.token ~= session.token then
            log_warn("[GateServer][on_bind_server_req] server({}) rebind! old will be kick!", server_id)
            client_mgr:call(server, "NID_GATE_KICK_CLIENT_NTF", { reason = KICK_RELOGIN })
        end
    end
    local service_name = sid2name(server_id)
    log_info("[GateServer][on_bind_server_req] server({}-{}) bind!", server_id, service_name)
    session.server_name = service_name
    session.server_id = server_id
    self.servers[server_id] = session
end

function GateServer:on_bind_service_req(session, message, body, response)
    log_debug("[GateServer][on_bind_service_req]) body({}))", body)
    local client_id, server_id = body.client_id, body.server_id
    local client = self.clients[client_id]
    if client then
        socket_mgr.map_server(client_id, session.server_id, session.token)
        log_info("[GateServer][on_bind_service_req] service({}-{}) bind!", client_id, server_id)
        return
    end
    log_err("[GateServer][on_bind_service_req] not client player({})", client_id)
end

function GateServer:rpc_update_verify_code(message, user_id, verify_code)
    log_debug("[GateServer][rpc_update_verify_code] open_id({}) verify_code({})!", user_id, verify_code)
    self.verify_codes[user_id] = { code = verify_code, time = quanta.now + MINUTE_5_S }
    return SUCCESS
end

--连接信息
----------------------------------------------------------------------
--客户端连上
function GateServer:on_socket_accept(session)
    log_debug("[GateServer][on_socket_accept] {} connected!", session.token)
end

--客户端连接断开
function GateServer:on_socket_error(session, token, err)
    local client_id = session.node_id
    if client_id then
        local servers = socket_mgr.query_servers(client_id)
        log_err("[GateServer][on_socket_error] client({}-{}) lost servers: {} because: {}!", token, client_id, servers, err)
        for _, server_id in pairs(servers or {}) do
            local server = self.servers[server_id]
            client_mgr:call(server, "NID_GATE_LOST_CLIENT_NTF", { player_id = client_id }, client_id)
        end
        socket_mgr.map_client(client_id, 0)
        self.clients[client_id] = nil
        session.client_id = nil
        return
    end
    local server_id = session.server_id
    if server_id then
        local kickouts = {}
        session.server_id = nil
        self.servers[server_id] = nil
        for cli_id, client in pairs(self.clients) do
            if socket_mgr.check_service(server_id, cli_id) then
                socket_mgr.map_client(cli_id, 0)
                if self.main_service == session.service_name then
                    kickouts[cli_id] = client
                end
            end
        end
        for cli_id, client in ipairs(kickouts) do
            client_mgr:call(client, "NID_GATE_KICK_CLIENT_NTF", { reason = KICK_CRASH })
            self.clients[cli_id] = nil
        end
        log_err("[GateServer][on_socket_error] server({}-{}) lost, because: {}!", token, client_id, err)
    end
end

quanta.gate_svr = GateServer()

return GateServer
