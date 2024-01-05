--robot_case.lua
local log_err   = logger.err
local sformat   = string.format

local event_mgr = quanta.get("event_mgr")

local NodeSwitch = {
    IF      = import("robot/nodes/node_if.lua"),
    GM      = import("robot/nodes/node_gm.lua"),
    REQ     = import("robot/nodes/node_req.lua"),
    NTF     = import("robot/nodes/node_ntf.lua"),
    SOCK    = import("robot/nodes/node_sock.lua"),
    CASE    = import("robot/nodes/node_case.lua"),
    WAIT    = import("robot/nodes/node_wait.lua"),
    GOAL    = import("robot/nodes/node_goal.lua"),
}

local RobotCase = class()
local prop = property(RobotCase)
prop:reader("root", nil)        --root
prop:reader("rewind", nil)      --rewind
prop:reader("actor", nil)       --actor
prop:reader("current", nil)     --current
prop:reader("childs", {})       --childs
prop:reader("variables", {})    --variables
prop:accessor("parent", nil)    --parent

function RobotCase:__init(actor)
    self.actor = actor
end

function RobotCase:load(file)
    local cconf = import(sformat("robot/cases/%s.lua", file))
    if not cconf then
        return false
    end
    for id, conf in pairs(cconf.nodes) do
        self:create_node(id, conf)
    end
    self.root = cconf.root
    self.current = cconf.root
    self.rewind = cconf.rewind or cconf.root
    return true
end

--沉睡ms
function RobotCase:create_node(id, conf)
    local Node = NodeSwitch[conf.type]
    if not Node then
        log_err("[RobotCase][create_node] node {} not exist", conf)
        return
    end
    local node = Node(self)
    if not node:load(conf) then
        log_err("[RobotCase][create_node] node {} load failed", conf)
        return
    end
    self.childs[id] = node
end

function RobotCase:run_next(child)
    self.current = child
    if self.actor:caeck_case(self) then
        event_mgr:fire_frame(function()
            self:update()
        end)
    end
end

--目标完成
function RobotCase:finish()
    self.current = self.rewind
    if self.parent then
        self.actor:run_case(self.parent)
        return
    end
end

--目标失败
function RobotCase:failed(err)
    self.current = self.rewind
    if self.parent then
        self.parent:failed()
        return
    end
end

--更新
function RobotCase:update()
    if not self.current then
        self:finish()
        return
    end
    local node = self.childs[self.current]
    if not node then
        self:finish()
        return
    end
    node:action()
end

return RobotCase
