--login.lua
local mrandom               = math.random
local log_warn              = logger.warn
local log_info              = logger.info
local tdelete               = table_ext.delete
local trandarray            = table_ext.random_array

local protobuf_mgr          = quanta.get("protobuf_mgr")

local PLATFORM_GUEST        = protobuf_mgr:enum("platform_type", "PLATFORM_GUEST")
local PLATFORM_PASSWORD     = protobuf_mgr:enum("platform_type", "PLATFORM_PASSWORD")

local HEARTBEAT_REQ         = protobuf_mgr:msg_id("NID_HEARTBEAT_REQ")
local RANDOM_NAME_REQ       = protobuf_mgr:msg_id("NID_LOGIN_RANDOM_NAME_REQ")
local ROLE_CREATE_REQ       = protobuf_mgr:msg_id("NID_LOGIN_ROLE_CREATE_REQ")
local ROLE_CHOOSE_REQ       = protobuf_mgr:msg_id("NID_LOGIN_ROLE_CHOOSE_REQ")
local ROLE_DELETE_REQ       = protobuf_mgr:msg_id("NID_LOGIN_ROLE_DELETE_REQ")
local ACCOUNT_LOGIN_REQ     = protobuf_mgr:msg_id("NID_LOGIN_ACCOUNT_LOGIN_REQ")
local ACCOUNT_RELOAD_REQ    = protobuf_mgr:msg_id("NID_LOGIN_ACCOUNT_RELOAD_REQ")
local ROLE_LOGIN_REQ        = protobuf_mgr:msg_id("NID_LOGIN_ROLE_LOGIN_REQ")
local ROLE_LOGOUT_REQ       = protobuf_mgr:msg_id("NID_LOGIN_ROLE_LOGOUT_REQ")
local ROLE_RELOAD_REQ       = protobuf_mgr:msg_id("NID_LOGIN_ROLE_RELOAD_REQ")

local LoginModule = mixin()
local prop = property(LoginModule)
prop:reader("roles", {})            --roles
prop:reader("user_id", nil)         --user_id
prop:reader("player_id", nil)       --player_id
prop:reader("gate_ip", nil)         --gate_ip
prop:reader("gate_port", nil)       --gate_port
prop:reader("lobby", nil)           --lobby
prop:reader("lobby_token", nil)     --lobby_token
prop:reader("account_token", nil)   --account_token
prop:reader("conn_name", nil)
prop:reader("serial", 1)

function LoginModule:__init()
end

function LoginModule:connect_login()
    if self:connect(self.ip, self.port, true) then
        self.conn_name = "login"
        return true
    end
    return false
end

function LoginModule:connect_gateway()
    if self:connect(self.gate_ip, self.gate_port, true) then
        self.conn_name = "gateway"
        return true
    end
    return false
end


function LoginModule:send_heartbeat()
    if self.conn_name then
        local req_data = { time = quanta.now, serial = self.serial }
        local ok, res = self:call(HEARTBEAT_REQ, req_data)
        if ok then
            self.serial = res.serial
        end
    end
end

function LoginModule:guest_login_req()
    local req_data = {
        openid = self.open_id,
        token = self.access_token,
        platform = PLATFORM_GUEST
    }
    local ok, res = self:call(ACCOUNT_LOGIN_REQ, req_data)
    if self:check_callback(ok, res) then
        log_warn("[LoginModule][guest_login_req] robot:%s, ok=%s, res=%s", self.index, ok, res)
        return false
    end
    self.roles = res.roles
    self.user_id = res.user_id
    log_info("[LoginModule][guest_login_req] robot:%s success", self.index)
    return true
end

function LoginModule:account_login_req()
    local req_data = {
        openid = self.open_id,
        token = self.access_token,
        platform = PLATFORM_PASSWORD
    }
    local ok, res = self:call(ACCOUNT_LOGIN_REQ, req_data)
    if self:check_callback(ok, res) then
        log_warn("[LoginModule][account_login_req] robot:%s, ok=%s, res=%s", self.index, ok, res)
        return false
    end
    self.roles = res.roles
    self.user_id = res.user_id
    log_info("[LoginModule][account_login_req] robot:%s success", self.index)
    return true
end

function LoginModule:random_name_req()
    local ok, res = self:call(RANDOM_NAME_REQ, {})
    if self:check_callback(ok, res) then
        log_warn("[LoginModule][random_name_req] robot:%s, ok=%s, res=%s", self.index, ok, res)
        return
    end
    log_info("[LoginModule][random_name_req] robot:%s success", self.index)
    return res.name
end

function LoginModule:create_role_req(name)
    local req_data = {
        name = name,
        user_id = self.user_id,
        gender = mrandom(1, 2)
    }
    local ok, res = self:call(ROLE_CREATE_REQ, req_data)
    if self:check_callback(ok, res) then
        log_warn("[LoginModule][create_role_req] robot:%s, ok=%s, res=%s", self.index, ok, res)
        return false
    end
    local roles = self.roles
    roles[#roles + 1] = res.role
    log_info("[LoginModule][create_role_req] robot:%s success", self.index)
    return true
end

function LoginModule:choose_role_req()
    local role = trandarray(self.roles)
    if not role then
        log_warn("[LoginModule][choose_role_req] robot:%s roles is empty", self.index)
        return false
    end
    local req_data = {
        role_id = role.role_id,
        user_id = self.user_id,
    }
    local ok, res = self:call(ROLE_CHOOSE_REQ, req_data)
    if self:check_callback(ok, res) then
        log_warn("[LoginModule][choose_role_req] robot:%s, ok=%s, res=%s", self.index, ok, res)
        return false
    end
    self.lobby = res.lobby
    self.gate_ip = res.addr
    self.gate_port = res.port
    self.lobby_token = res.token
    self.player_id = role.role_id
    log_info("[LoginModule][choose_role_req] robot:%s success", self.index)
    return true
end

function LoginModule:delete_role_req()
    local role = trandarray(self.roles)
    if not role then
        log_warn("[LoginModule][delete_role_req] robot:%s roles is empty", self.index)
        return false
    end
    local req_data = {
        role_id = role.role_id,
        user_id = self.user_id,
    }
    local ok, res = self:call(ROLE_DELETE_REQ, req_data)
    if self:check_callback(ok, res) then
        log_warn("[LoginModule][delete_role_req] robot:%s, ok=%s, res=%s", self.index, ok, res)
        return false
    end
    tdelete(self.roles, role)
    log_info("[LoginModule][delete_role_req] robot:%s success", self.index)
    return true
end

function LoginModule:account_reload_req()
    local req_data = {
        openid = self.openid,
        account_token = self.account_token
    }
    local ok, res = self:call(ACCOUNT_RELOAD_REQ, req_data)
    if self:check_callback(ok, res) then
        log_warn("[LoginModule][account_reload_req] robot:%s, ok=%s, res=%s", self.index, ok, res)
        return false
    end
    self.roles = res.roles
    self.user_id = res.user_id
    log_info("[LoginModule][account_reload_req] robot:%s success", self.index)
    return true
end

function LoginModule:role_login_req()
    local req_data = {
        lobby = self.lobby,
        user_id = self.user_id,
        role_id = self.player_id,
        token = self.lobby_token
    }
    local ok, res = self:call(ROLE_LOGIN_REQ, req_data)
    if self:check_callback(ok, res) then
        log_warn("[LoginModule][role_login_req] robot:%s, ok=%s, res=%s", self.index, ok, res)
        return false
    end
    log_info("[LoginModule][role_login_req] robot:%s success", self.index)
    return true
end

function LoginModule:role_logout_req()
    local req_data = { role_id = self.player_id }
    local ok, res = self:call(ROLE_LOGOUT_REQ, req_data)
    if self:check_callback(ok, res) then
        log_warn("[LoginModule][role_logout_req] robot:%s, ok=%s, res=%s", self.index, ok, res)
        return false
    end
    self.account_token = res.account_token
    self.player_id = nil
    log_info("[LoginModule][role_logout_req] robot:%s success", self.index)
    return true
end

function LoginModule:role_reload_req()
    local req_data = {
        lobby = self.lobby,
        user_id = self.user_id,
        role_id = self.player_id,
        token = self.lobby_token
    }
    local ok, res = self:call(ROLE_RELOAD_REQ, req_data)
    if self:check_callback(ok, res) then
        log_warn("[LoginModule][role_reload_req] robot:%s, ok=%s, res=%s", self.index, ok, res)
        return false
    end
    log_info("[LoginModule][role_reload_req] robot:%s success", self.index)
    return true
end

return LoginModule

