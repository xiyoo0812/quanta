-- robot.lua
local qfailed       = quanta.failed
local log_debug     = logger.debug

local QueueFIFO     = import("container/queue_fifo.lua")
local LoginModule   = import("robot/module/login.lua")
local SessionModule = import("robot/module/session.lua")

local update_mgr    = quanta.get("update_mgr")

local Robot = class(nil, SessionModule, LoginModule)
local prop = property(Robot)
prop:accessor("ip", nil)            --ip
prop:accessor("port", nil)          --port
prop:accessor("open_id", nil)       --open_id
prop:accessor("access_token", nil)  --open_id访问令牌
prop:accessor("active_code", nil)   --激活码
prop:reader("device_id", nil)       --device_id
prop:reader("messages", nil)        --收到的消息回包

function Robot:__init()
    self.messages = QueueFIFO()
    --注册心跳循环
    update_mgr:attach_second5(self)
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

function Robot:get_title()
    return self.open_id
end

function Robot:on_second5()
    --心跳
    self:send_heartbeat()
end

function Robot:push_message(cmd_id, msg)
    log_debug("recv server msg:%d %s",cmd_id, msg)
    msg.cmd_id = cmd_id
    self.messages:push(msg)
end

function Robot:get_messages()
    return self.messages:pop()
end

function Robot:clear_messages()
    self.messages.clear()
end

function Robot:update()
end

return Robot
