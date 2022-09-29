-- robot.lua
local qfailed       = quanta.failed

local LoginModule   = import("robot/module/login.lua")
local SessionModule = import("robot/module/session.lua")

local event_mgr     = quanta.get("event_mgr")
local update_mgr    = quanta.get("update_mgr")

local Robot = class(nil, SessionModule, LoginModule)
local prop = property(Robot)
prop:accessor("ip", nil)            --ip
prop:accessor("port", nil)          --port
prop:accessor("open_id", nil)       --open_id
prop:accessor("access_token", nil)  --open_id访问令牌
prop:accessor("active_code", nil)   --激活码
prop:accessor("messages", {})       --收到的消息回包

function Robot:__init()
    --注册心跳循环
    update_mgr:attach_second5(self)
end

--检查错误码
function Robot:check_callback(ok, res)
    if not ok or qfailed(res.error_code) then
        return true
    end
    return false
end

function Robot:on_second5()
    --心跳
    self:send_heartbeat()
end

function Robot:watch_message()
    event_mgr:add_listener(self, "on_server_message")
end

function Robot:on_server_message(cmd_id, msg)
    self.messages[cmd_id] = msg
end

function Robot:update()
end

return Robot
