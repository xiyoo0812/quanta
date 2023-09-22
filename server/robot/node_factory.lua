--node_factory.lua

local log_err       = logger.err
local log_info      = logger.info
local tinsert       = table.insert

local event_mgr    = quanta.get("event_mgr")

local NodeFactory = singleton()
local prop = property(NodeFactory)
prop:accessor("nodes", {})      --nodes
prop:accessor("factorys", {})   --factorys

function NodeFactory:__init()
    event_mgr:fire_frame(function()
        log_info("[NodeFactory] load factorys")
        for _, factory in ipairs(self.factorys) do
            factory:load()
        end
    end)
end

function NodeFactory:register(id, func)
    log_info("[NodeFactory][register] Node {} register!", id)
    self.nodes[id] = func
end

function NodeFactory:register_factory(factory)
    log_info("[NodeFactory][register] factory {} register!", factory)
    tinsert(self.factorys, factory)
end

function NodeFactory:create(id)
    local func = self.nodes[id]
    if not func then
        log_err("[NodeFactory][create] Node {} not define!", id)
        return
    end
    return func()
end

quanta.node_factory = NodeFactory()

return NodeFactory
