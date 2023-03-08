-- bb_component.lua
local log_debug     = logger.debug

local BBcomponent = mixin()
local prop = db_property(BBcomponent, "task")
prop:store_value("main_task", 2)    --main_task
prop:store_values("tasks", {})      --tasks

function BBcomponent:__init()
    self:load_taskt_db()
end

function BBcomponent:on_db_task_load(sheet)
    log_debug("[SPlayer][on_db_task_load], sheet:%s", sheet)
end

function BBcomponent:add_task(id, status)
    self:set_tasks_field(id, status)
end

function BBcomponent:del_task(id)
    self:del_tasks_field(id)
end

return BBcomponent
