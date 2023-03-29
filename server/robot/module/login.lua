--login.lua
local mrandom               = math.random
local log_warn              = logger.warn
local log_debug             = logger.debug
local tinsert               = table.insert
local tdelete               = qtable.delete
local trandarray            = qtable.random_array

local protobuf_mgr          = quanta.get("protobuf_mgr")

local PLATFORM_GUEST        = protobuf_mgr:enum("platform_type", "PLATFORM_GUEST")
local PLATFORM_PASSWORD     = protobuf_mgr:enum("platform_type", "PLATFORM_PASSWORD")

local LoginModule = mixin()
local prop = property(LoginModule)
prop:reader("roles", {})            --roles
prop:reader("user_id", nil)         --user_id
prop:reader("player_id", nil)       --player_id
prop:reader("gate_ip", nil)         --gate_ip
prop:reader("gate_port", nil)       --gate_port
prop:reader("lobby", nil)           --lobby
prop:reader("lobby_token", nil)     --lobby_token
prop:reader("login_connect", false)
prop:reader("lobby_connect", false)
prop:reader("login_success", false)
prop:reader("serial", 1)

function LoginModule:__init()
end

function LoginModule:connect_login()
    self.lobby_connect = false
    self.login_connect = false
    if self:connect(self.ip, self.port, true) then
        self.login_connect = true
        return true
    end
    return false
end

function LoginModule:connect_gateway()
    self.lobby_connect = false
    if self:connect(self.gate_ip, self.gate_port, true) then
        self.lobby_connect = true
        return true
    end
    return false
end


function LoginModule:send_heartbeat()
    if self.login_success then
        local req_data = { time = quanta.now, serial = self.serial }
        local ok, res = self:call("NID_HEARTBEAT_REQ", req_data)
        if ok then
            self.serial = res.serial
        end
    end
end

function LoginModule:guest_login_req()
    local req_data = {
        openid = self.open_id,
        session = self.access_token,
        device_id = self.device_id,
        platform = PLATFORM_GUEST
    }
    local ok, res = self:call("NID_LOGIN_ACCOUNT_LOGIN_REQ", req_data)
    if self:check_callback(ok, res) then
        log_warn("[LoginModule][guest_login_req] robot:%s, ok=%s, res=%s", self:get_title(), ok, res)
        return false
    end
    self.roles = res.roles
    self.user_id = res.user_id
    log_debug("[LoginModule][guest_login_req] robot:%s success", self:get_title())
    return true
end

function LoginModule:account_login_req()
    local req_data = {
        openid = self.open_id,
        session = self.access_token,
        device_id = self.device_id,
        platform = PLATFORM_PASSWORD,
    }
    local ok, res = self:call("NID_LOGIN_ACCOUNT_LOGIN_REQ", req_data)
    log_warn("[LoginModule][account_login_req] robot:%s, ok=%s, res=%s", self:get_title(), ok, req_data)
    if self:check_callback(ok, res) then
        log_warn("[LoginModule][account_login_req] robot:%s, ok=%s, res=%s", self:get_title(), ok, res)
        return false
    end
    self.roles = res.roles
    self.user_id = res.user_id
    log_debug("[LoginModule][account_login_req] robot:%s success", self:get_title())
    return true
end

function LoginModule:login_server()
    if self.login_success then
        return true
    end
    if not self:connect_login() then
        return false, "loginsvr connect failed!"
    end
    if not self:account_login_req() then
        return false, "account login failed!"
    end
    if #self.roles == 0 then
        local name = self:random_name_req()
        if not name then
            return false, "random name failed!"
        end
        if not self:create_role_req(name) then
            return false, "create role failed!"
        end
    end
    if not self:choose_role_req() then
        return false, "choose role failed!"
    end
    if not self:connect_gateway() then
        return false, "gateway connect failed!"
    end
    if not self:role_login_req() then
        return false, "role login failed!"
    end
    return true
end

function LoginModule:logout_server()
    if self.login_success then
        self:role_logout_req()
    end
    self:disconnect()
    return true
end

function LoginModule:random_name_req()
    local ok, res = self:call("NID_LOGIN_RANDOM_NAME_REQ", {})
    if self:check_callback(ok, res) then
        log_warn("[LoginModule][random_name_req] robot:%s, ok=%s, res=%s", self:get_title(), ok, res)
        return
    end
    log_debug("[LoginModule][random_name_req] robot:%s success", self:get_title())
    return res.name
end

function LoginModule:create_role_req(name)
    local custom = { model = 101, color = 0, head = 0 }
    local req_data = {
        name = name,
        user_id = self.user_id,
        gender = mrandom(1, 2),
        custom = protobuf_mgr:encode_byname("ncmd_cs.rolemodel", custom)
    }
    local ok, res = self:call("NID_LOGIN_ROLE_CREATE_REQ", req_data)
    if self:check_callback(ok, res) then
        log_warn("[LoginModule][create_role_req] robot:%s, ok=%s, res=%s", self:get_title(), ok, res)
        return false
    end
    tinsert(self.roles, res.role)
    log_debug("[LoginModule][create_role_req] robot:%s success", self:get_title())
    return true
end

function LoginModule:choose_role_req()
    local role = trandarray(self.roles)
    if not role then
        log_warn("[LoginModule][choose_role_req] robot:%s roles is empty", self:get_title())
        return false
    end
    local req_data = {
        role_id = role.role_id,
        user_id = self.user_id,
    }
    local ok, res = self:call("NID_LOGIN_ROLE_CHOOSE_REQ", req_data)
    if self:check_callback(ok, res) then
        log_warn("[LoginModule][choose_role_req] robot:%s, ok=%s, res=%s", self:get_title(), ok, res)
        return false
    end
    self.lobby = res.lobby
    self.gate_ip = res.addr
    self.gate_port = res.port
    self.lobby_token = res.token
    self.player_id = role.role_id
    log_debug("[LoginModule][choose_role_req] robot:%s success", self:get_title())
    return true
end

function LoginModule:delete_role_req()
    local role = trandarray(self.roles)
    if not role then
        log_warn("[LoginModule][delete_role_req] robot:%s roles is empty", self:get_title())
        return false
    end
    local req_data = {
        role_id = role.role_id,
        user_id = self.user_id,
    }
    local ok, res = self:call("NID_LOGIN_ROLE_DELETE_REQ", req_data)
    if self:check_callback(ok, res) then
        log_warn("[LoginModule][delete_role_req] robot:%s, ok=%s, res=%s", self:get_title(), ok, res)
        return false
    end
    tdelete(self.roles, role)
    log_debug("[LoginModule][delete_role_req] robot:%s success", self:get_title())
    return true
end

function LoginModule:account_reload_req()
    local req_data = {
        openid = self.openid,
        device_id = self.device_id,
        account_token = self.access_token
    }
    local ok, res = self:call("NID_LOGIN_ACCOUNT_RELOAD_REQ", req_data)
    if self:check_callback(ok, res) then
        log_warn("[LoginModule][account_reload_req] robot:%s, ok=%s, res=%s", self:get_title(), ok, res)
        return false
    end
    self.roles = res.roles
    self.user_id = res.user_id
    log_debug("[LoginModule][account_reload_req] robot:%s success", self:get_title())
    return true
end

function LoginModule:role_login_req()
    local req_data = {
        lobby = self.lobby,
        user_id = self.user_id,
        role_id = self.player_id,
        token = self.lobby_token,
        open_id = self.open_id
    }
    local ok, res = self:call("NID_LOGIN_ROLE_LOGIN_REQ", req_data)
    if self:check_callback(ok, res) then
        log_warn("[LoginModule][role_login_req] robot:%s, ok=%s, res=%s", self:get_title(), ok, res)
        return false
    end
    self.lobby_token = res.token
    log_debug("[LoginModule][role_login_req] robot:%s success", self:get_title())
    return true
end

function LoginModule:role_logout_req()
    local req_data = { role_id = self.player_id }
    local ok, res = self:call("NID_LOGIN_ROLE_LOGOUT_REQ", req_data)
    if self:check_callback(ok, res) then
        log_warn("[LoginModule][role_logout_req] robot:%s, ok=%s, res=%s", self:get_title(), ok, res)
        return false
    end
    self.player_id = nil
    log_debug("[LoginModule][role_logout_req] robot:%s success", self:get_title())
    return true
end

function LoginModule:role_reload_req()
    local req_data = {
        lobby = self.lobby,
        user_id = self.user_id,
        role_id = self.player_id,
        token = self.lobby_token
    }
    local ok, res = self:call("NID_LOGIN_ROLE_RELOAD_REQ", req_data)
    if self:check_callback(ok, res) then
        log_warn("[LoginModule][role_reload_req] robot:%s, ok=%s, res=%s", self:get_title(), ok, res)
        return false
    end
    self.lobby_token = res.token
    log_debug("[LoginModule][role_reload_req] robot:%s success", self:get_title())
    return true
end

return LoginModule

