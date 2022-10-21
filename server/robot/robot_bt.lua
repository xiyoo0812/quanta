-- robot_bt.lua
local log_err       = logger.err
local log_info      = logger.info
local sformat       = string.format
local env_number    = environ.number

local LuaBT         = import("luabt/luabt.lua")
local Robot         = import("robot/robot.lua")

local report_mgr    = quanta.get("report_mgr")
local node_factory  = quanta.get("node_factory")

local RobotBT = class(Robot)
local prop = property(RobotBT)
prop:reader("index", nil)           --index
prop:reader("robot_id", nil)        --robot_id
prop:reader("running", true)        --running
prop:reader("lua_tree", nil)        --行为树
prop:accessor("wait_time", 0)       --sleep

function RobotBT:__init(conf, index)
    self.index = index
    self.robot_id = index + conf.start
    --创建行为树
    local tree_id = env_number("QUANTA_TREE_ID", conf.tree_id)
    local node = node_factory:create(tree_id)
    if not node then
        log_err("[RobotBT][init] robot(%s) create tree(%s) failed!", index, tree_id)
        return
    end
    self.lua_tree = LuaBT(self, node)
    --设置行为树参数
    if conf.args then
        local ok, args = pcall(load(sformat("return %s", conf.args)))
        if not ok then
            log_err("[RobotBT][init] robot(%s) load args failed: %s", index, args)
            return
        end
        if args and args[index] then
            self.lua_tree:set_args(args[index])
        end
    end
end

function RobotBT:get_title()
    return self.robot_id
end

function RobotBT:get_board()
    return self.lua_tree.blackboard
end

function RobotBT:report(event, ...)
    report_mgr:robot_report(self.robot_id, event, ...)
end

function RobotBT:update()
    --清理状态
    self.wait_time = nil
    --行为树执行
    if not self.lua_tree then
        return 0
    end
    if self.lua_tree:tick() then
        log_info("lua_tree tick finish")
        self.running = false
        return 0
    end
    --返回wait_time
    return self.wait_time or 1000
end

return RobotBT
