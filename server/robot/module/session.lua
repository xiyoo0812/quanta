-- session.lua
local mrandom       = math.random
local tunpack       = table.unpack
local tinsert       = table.insert
local log_warn      = logger.warn
local log_debug     = logger.debug
local guid_encode   = codec.guid_encode
local trandarray    = qtable.random_array

local event_mgr     = quanta.get("event_mgr")
local protobuf_mgr  = quanta.get("protobuf_mgr")

local NetClient     = import("network/net_client.lua")

local PLATPASSWORD  = protobuf_mgr:enum("platform_type", "PLATFORM_PASSWORD")

local SessionModule = mixin()
local prop = property(SessionModule)
prop:reader("client", nil)
prop:reader("cmd_doers", {})
prop:reader("login_success", false)

function SessionModule:__init()
end

function SessionModule:disconnect()
    if self.client then
        self.client:close()
    end
end

function SessionModule:connect(ip, port, block)
    if self.client then
        self.client:close()
    end
    self.client = NetClient(self, ip, port)
    return self.client:connect(block)
end

-- 连接成回调
function SessionModule:on_socket_connect(client)
    log_debug("[SessionModule][on_socket_connect] {}", self.open_id)
end

-- 连接关闭回调
function SessionModule:on_socket_error(client, token, err)
    log_debug("[SessionModule][on_socket_error] {}, err:{}", self.open_id, err)
end

-- ntf消息回调
function SessionModule:on_socket_rpc(client, cmd_id, body)
    local doer = self.cmd_doers[cmd_id]
    if not doer then
        self:push_message(cmd_id, body)
        return
    end
    local module, handler = tunpack(doer)
    module[handler](self, body)
end

-- 注册NTF消息处理
function SessionModule:register_doer(pb_name, module, handler)
    local cmdid = protobuf_mgr:enum("NCmdId", pb_name)
    self.cmd_doers[cmdid] = {module, handler}
end

function SessionModule:conv_type(cmdid)
    if type(cmdid) == "string" then
        cmdid = protobuf_mgr:msg_id(cmdid)
    end
    if cmdid < 10000 then
        return 0
    end
    return (cmdid // 1000) % 10
end

function SessionModule:send(cmdid, data)
    if self.client then
        return self.client:send(cmdid, data, self:conv_type(cmdid))
    end
end

function SessionModule:call(cmdid, data)
    if type(cmdid) == "string" then
        cmdid = protobuf_mgr:msg_id(cmdid)
    end
    if self.client then
        local srv_type = self:conv_type(cmdid)
        local ok, resp = self.client:call(cmdid, data, srv_type)
        if cmdid ~= 1001 then
            event_mgr:notify_listener("on_call_message", self, cmdid, ok, resp)
            if ok and srv_type == 0 and resp then
                self:push_message(cmdid, resp)
            end
        end
        return ok, resp
    end
    return false
end

-- 等待NTF命令或者非RPC命令
function SessionModule:wait(cmdid, time)
    if self.client then
        if type(cmdid) == "string" then
            cmdid = protobuf_mgr:msg_id(cmdid)
        end
        return self.client:wait(cmdid, time)
    end
    return false
end

--登陆接口
-------------------------------------------------
function SessionModule:create_role_req(name)
    local custom = { model = 101, color = 0, head = 0 }
    local req_data = {
        name = name,
        user_id = self.user_id,
        gender = mrandom(1, 2),
        custom = protobuf_mgr:encode_byname("ncmd_cs.rolemodel", custom)
    }
    local ok, res = self:call("NID_LOGIN_ROLE_CREATE_REQ", req_data)
    if self:check_callback(ok, res) then
        log_warn("[LoginModule][create_role_req] robot:{}, ok={}, res={}", self:get_title(), ok, res)
        return false
    end
    tinsert(self.roles, res.role)
    log_debug("[LoginModule][create_role_req] robot:{} success", self:get_title())
    return true
end

function SessionModule:account_login_req()
    local req_data = {
        openid = self.open_id,
        session = self.access_token,
        device_id = self.device_id,
        platform = PLATPASSWORD,
    }
    local ok, res = self:call("NID_LOGIN_ACCOUNT_LOGIN_REQ", req_data)
    if self:check_callback(ok, res) then
        log_warn("[LoginModule][account_login_req] robot:{}, ok={}, res={}", self.open_id, ok, res)
        return false
    end
    self.roles = res.roles
    self.user_id = res.user_id
    log_debug("[LoginModule][account_login_req] robot:{} success", self.open_id)
    return true
end

function SessionModule:choose_role_req()
    local role = trandarray(self.roles)
    if not role then
        log_warn("[SessionModule][choose_role_req] robot:{} roles is empty", self.open_id)
        return false
    end
    local req_data = {
        role_id = role.role_id,
        user_id = self.user_id,
    }
    local ok, res = self:call("NID_LOGIN_ROLE_CHOOSE_REQ", req_data)
    if self:check_callback(ok, res) then
        log_warn("[SessionModule][choose_role_req] robot:{}, ok={}, res={} req_data={}", self.open_id, ok, res, req_data)
        return false
    end
    self.lobby = res.lobby
    self.gate_ip = res.addrs[1]
    self.gate_port = res.port
    self.lobby_token = res.token
    self.player_id = role.role_id
    log_debug("[SessionModule][choose_role_req] robot:{} success", self.open_id)
    return true
end

function SessionModule:role_login_req()
    local req_data = {
        lobby = self.lobby,
        user_id = self.user_id,
        role_id = self.player_id,
        token = self.lobby_token,
        open_id = self.open_id
    }
    local ok, res = self:call("NID_LOGIN_ROLE_LOGIN_REQ", req_data)
    if self:check_callback(ok, res) then
        log_warn("[SessionModule][role_login_req] robot:{}, ok={}, res={}", self.open_id, ok, res)
        return false
    end
    self.lobby_token = res.token
    log_debug("[SessionModule][role_login_req] robot:{} success", self.open_id)
    return true
end

function SessionModule:login_server()
    if self.login_success then
        return true
    end
    if not self:connect(self.ip, self.port, true) then
        return "loginsvr connect failed!"
    end
    if not self:account_login_req() then
        return false, "account login failed!"
    end
    if #self.roles == 0 then
        if not self:create_role_req(guid_encode()) then
            return false, "create role failed!"
        end
    end
    if not self:choose_role_req() then
        return false, "choose role failed!"
    end
    if not self:connect(self.gate_ip, self.gate_port, true) then
        return "gateway connect failed!"
    end
    if not self:role_login_req() then
        return false, "role login failed!"
    end
    log_debug("[SessionModule][login_server] robot:{} login success", self.open_id)
end

return SessionModule
