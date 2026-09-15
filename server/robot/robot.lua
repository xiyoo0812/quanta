-- robot.lua
local log_err       = logger.err
local log_debug     = logger.debug
local qfailed       = quanta.failed
local tinsert       = table.insert
local sformat       = string.format
local sname2sid     = service.name2sid
local guid_string   = codec.guid_string

local RobotCase     = import("robot/robot_case.lua")
local TcpClient     = import("network/tcp_client.lua")

local thread_mgr    = quanta.get("thread_mgr")
local protobuf_mgr  = quanta.get("protobuf_mgr")

local RELAY_SELF    = luabus.relay_type.SELF
local RELAY_SERVICE = luabus.relay_type.SERVICE

local Robot = class()
local prop = property(Robot)
prop:reader("ip", nil)              --ip
prop:reader("port", nil)            --port
prop:reader("open_id", nil)         --open_id
prop:reader("client", nil)          --client
prop:reader("user_id", nil)         --user_id
prop:reader("cur_case", nil)        --cur_case
prop:reader("next_case", nil)       --next_case
prop:reader("player_id", nil)       --player_id
prop:reader("device_id", nil)       --device_id
prop:reader("relay_type", nil)      --relay_type
prop:reader("hertz", 0)             --hertz
prop:reader("target_id", 0)         --target_id
prop:reader("running", false)       --running
prop:reader("messages", {})         --messages
prop:reader("variables", {})        --variables
prop:reader("login_success", false)

function Robot:__init(ip, port, open_id)
    self.ip = ip
    self.port = port
    self.open_id = open_id
    self.relay_type = RELAY_SELF
    self.device_id = guid_string()
end

function Robot:connect(ip, port)
    if self.client then
        self.client:close()
    end
    self.login_success = false
    self.client = TcpClient(ip, port)
    return self.client:connect()
end

function Robot:change_service(service)
    self.relay_type = RELAY_SERVICE
    self.target_id = sname2sid(service)
end

--检查错误码
function Robot:check_callback(ok, res)
    if not res then
        return ok
    end
    if qfailed(res.error_code, ok) then
        return true
    end
    return false
end

function Robot:check_case(case)
    return self.cur_case == case
end

function Robot:run_case(case)
    self.next_case = case
end

function Robot:mount_node(data)
    if self.cur_case then
        return self.cur_case:mount_node(data)
    end
end

function Robot:create_case_by_data(data)
    local case = RobotCase(self)
    if case:load_data(data) then
        return case
    end
    log_err("[Robot][create_case] load case {} failed!", data)
end

function Robot:create_case(file)
    local case = RobotCase(self)
    if case:load(file) then
        return case
    end
    log_err("[Robot][create_case] load case {} failed!", file)
end

function Robot:load_case(file, hertz)
    log_debug("[Robot][load_case] robot (%s) ready action!", self.open_id)
    local case = self:create_case(file)
    self:startup(case, hertz)
end

function Robot:startup(case, hertz)
    if case then
        self:run_case(case)
    end
    self.hertz = hertz or 1000
    if not self.running then
        self.running = true
        thread_mgr:fork(function()
            while self.running do
               self:on_update()
            end
        end)
    end
end

-- 获取状态
function Robot:get_status()
    local res = { running = self.running }
    if self.cur_case then
        res.case = self.cur_case:get_status()
    end
    return res
end

function Robot:stop()
    self.running = false
end

function Robot:stop_case()
    self.cur_case = nil
end

function Robot:on_update()
    if self.next_case then
        self.cur_case = self.next_case
        self.next_case = nil
    end
    if self.cur_case then
        self.cur_case:update()
    end
    thread_mgr:sleep(self.hertz)
end

function Robot:push_message(cmd_id, msg)
    tinsert(self.messages, {cmd_id = cmd_id, msg = msg })
end

function Robot:clear_messages()
    self.messages = {}
end

function Robot:send_gm(gm)
    if self.login_success then
        self:send("NID_GM_COMMAND_REQ", { command = sformat(gm, self.player_id) })
    end
end

function Robot:send(cmdid, data)
    if self.client then
        if type(cmdid) == "string" then
            cmdid = protobuf_mgr:msg_id(cmdid)
        end
        return self.client:send(cmdid, data, self.relay_type, self.target_id)
    end
end

function Robot:call(cmdid, data)
    if self.client then
        if type(cmdid) == "string" then
            cmdid = protobuf_mgr:msg_id(cmdid)
        end
        local ok, resp = self.client:call(cmdid, data, self.relay_type, self.target_id)
        if cmdid ~= 1001 then
            if ok and resp then
                self:push_message(cmdid, resp)
            end
        end
        return ok, resp
    end
    return false
end

-- 等待NTF命令或者非RPC命令
function Robot:wait(cmdid, time)
    if self.client then
        if type(cmdid) == "string" then
            cmdid = protobuf_mgr:msg_id(cmdid)
        end
        return self.client:wait(cmdid, time)
    end
    return false
end

-- 连接成回调
function Robot:on_socket_connect(client)
    log_debug("[Robot][on_socket_connect] {}-{}-{}", self.open_id, client.ip, client.port)
end

-- 连接关闭回调
function Robot:on_socket_error(client, token, err)
    log_debug("[Robot][on_socket_error] {}, err:{}, {}-{}", self.open_id, err, client.ip, client.port)
end

return Robot
