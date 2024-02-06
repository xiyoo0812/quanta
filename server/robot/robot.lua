-- robot.lua
local jpretty       = json.pretty
local log_err       = logger.err
local log_debug     = logger.debug
local qfailed       = quanta.failed
local sformat       = string.format
local guid_string   = codec.guid_string

local SessionModule = import("robot/module/session.lua")
local RobotCase     = import("robot/nodes/robot_case.lua")
local QueueFIFO     = import("container/queue_fifo.lua")

local event_mgr     = quanta.get("event_mgr")
local thread_mgr    = quanta.get("thread_mgr")

local Robot = class(nil, SessionModule)
local prop = property(Robot)
prop:accessor("ip", nil)            --ip
prop:accessor("port", nil)          --port
prop:accessor("open_id", nil)       --open_id
prop:reader("rate", 0)              --rate
prop:reader("case", nil)            --case
prop:reader("runtime", 0)           --runtime
prop:reader("user_id", nil)         --user_id
prop:reader("messages", nil)        --收到的消息回包
prop:reader("player_id", nil)       --player_id
prop:reader("device_id", nil)       --device_id
prop:reader("variables", {})        --variables
prop:reader("access_token", "123456")

function Robot:__init()
    self.device_id = guid_string()
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

function Robot:send_gm(gm)
    if self.login_success then
        self:send("NID_UTILITY_GM_COMMAND_REQ", { command = sformat(gm, self.player_id) })
    end
end

function Robot:bind_message_eueue()
    self.messages = QueueFIFO()
end

function Robot:check_case(case)
    return self.case == case
end

function Robot:run_case(case)
    self.case = case
    event_mgr:fire_frame(function()
        self:update(true)
    end)
end

function Robot:create_case(file)
    local case = RobotCase(self)
    if not case:load(file) then
        log_err("[Robot][create_case] load case {} failed!", file)
        return
    end
    return case
end

function Robot:load_case(file, rate)
    log_debug("[Robot][load_case] robot (%s) ready action!", self.open_id)
    local case = self:create_case(file)
    if case then
        self.rate = rate
        self:run_case(case)
    end
end

function Robot:stop_script()
    self.case = nil
end

function Robot:update(force)
    if self.case then
        thread_mgr:entry(self:address(), function()
            local now_ms = quanta.now_ms
            if force or now_ms - self.runtime > self.rate then
                self.runtime = quanta.now_ms
                self.case:update()
            end
        end)
    end
end

function Robot:push_message(cmd_id, msg)
    if self.messages then
        msg.req_cmd_id = cmd_id
        msg.cmd_id = cmd_id + 1
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

return Robot
