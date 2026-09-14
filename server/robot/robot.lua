-- robot.lua
local json          = require("ljson")

local jpretty       = json.pretty
local log_err       = logger.err
local log_debug     = logger.debug
local qfailed       = quanta.failed
local sformat       = string.format
local guid_string   = codec.guid_string

local Queue         = import("container/queue.lua")
local RobotCase     = import("robot/robot_case.lua")
local TcpClient     = import("network/tcp_client.lua")

local thread_mgr    = quanta.get("thread_mgr")
local protobuf_mgr  = quanta.get("protobuf_mgr")

local Robot = class()
local prop = property(Robot)
prop:reader("ip", nil)              --ip
prop:reader("port", nil)            --port
prop:reader("open_id", nil)         --open_id
prop:reader("hertz", 0)             --hertz
prop:reader("client", nil)          --client
prop:reader("user_id", nil)         --user_id
prop:reader("cur_case", nil)        --cur_case
prop:reader("next_case", nil)       --next_case
prop:reader("messages", nil)        --收到的消息回包
prop:reader("player_id", nil)       --player_id
prop:reader("device_id", nil)       --device_id
prop:reader("running", false)       --running
prop:reader("variables", {})        --variables
prop:reader("login_success", false)
prop:reader("access_token", "123456")

function Robot:__init(ip, port, open_id)
    self.ip = ip
    self.port = port
    self.open_id = open_id
    self.device_id = guid_string()
end

function Robot:connect(ip, port, block)
    if self.client then
        self.client:close()
    end
    self.login_success = false
    self.client = TcpClient(self, ip, port)
    return self.client:connect(block)
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

function Robot:bind_message_queue()
    self.messages = Queue()
end

function Robot:check_case(case)
    return self.cur_case == case
end

function Robot:run_case(case)
    self.next_case = case
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
    if case then
        self:run_case(case)
    end
    self.hertz = hertz
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
    if self.messages then
        msg.req_cmd_id = cmd_id
        msg.res_cmd_id = protobuf_mgr:callback_id(cmd_id)
        self.messages:push(jpretty(msg))
    end
end

function Robot:get_messages()
    if self.messages then
        return self.messages:pop()
    end
end

function Robot:clear_messages()
    if self.messages then
        self.messages.clear()
    end
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
        return self.client:send(cmdid, data)
    end
end

function Robot:call(cmdid, data)
    if self.client then
        if type(cmdid) == "string" then
            cmdid = protobuf_mgr:msg_id(cmdid)
        end
        local ok, resp = self.client:call(cmdid, data)
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
