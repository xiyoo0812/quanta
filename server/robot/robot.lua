-- robot.lua
local log_err           = logger.err
local log_info          = logger.info
local sformat           = string.format
local qfailed           = quanta.failed

local LuaBT             = import("luabt/luabt.lua")
local ROBOT_TREES       = import("robot/robot_tree.lua")
local LoginModule       = import("robot/module/login.lua")
local SessionModule     = import("robot/module/session.lua")

local update_mgr        = quanta.get("update_mgr")
local report_mgr        = quanta.get("report_mgr")

local Robot = class(nil, SessionModule, LoginModule)
local prop = property(Robot)
prop:reader("index", nil)           --index
prop:reader("robot_id", nil)        --robot_id
prop:reader("running", true)        --running
prop:reader("lua_tree", nil)        --行为树
prop:accessor("ip", nil)            --ip
prop:accessor("port", nil)          --port
prop:accessor("open_id", nil)       --open_id
prop:accessor("access_token", nil)  --open_id访问令牌
prop:accessor("active_code", nil)   --激活码
prop:accessor("wait_time", 0)       --sleep

function Robot:__init(conf, index)
    self.index = index
    self.robot_id = index + conf.start
    --创建行为树
    self.lua_tree = LuaBT(self, ROBOT_TREES[conf.tree_id])
    --设置行为树参数
    if conf.args then
        local ok, args = pcall(load(sformat("return %s", conf.args)))
        if not ok then
            log_err("[Robot][init] load robot args(%s) failed: %s", index, args)
            return
        end
        if args and args[index] then
            self.lua_tree:set_args(args[index])
        end
    end
    --注册心跳循环
    update_mgr:attach_second5(self)
end

function Robot:get_board()
    return self.lua_tree.blackboard
end

--检查错误码
function Robot:check_callback(ok, res)
    if not ok or qfailed(res.error_code) then
        return true
    end
    return false
end

function Robot:report(event, ...)
    report_mgr:robot_report(self.robot_id, event, ...)
end

function Robot:on_second5()
    --心跳
    self:send_heartbeat()
end

function Robot:update()
    --清理状态
    self.wait_time = nil
    --行为树执行
    if self.lua_tree:tick() then
        log_info("lua_tree tick finish")
        self.running = false
        return 0
    end
    --返回wait_time
    return self.wait_time or 1000
end

return Robot
