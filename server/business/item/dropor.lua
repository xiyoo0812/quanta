--dropor.lua
--道具掉落器
local pairs         = pairs

local config_mgr    = quanta.get("config_mgr")
local drop_db       = config_mgr:init_group_table("drop", "id")

local Random        = import("basic/random.lua")

local ALONE         = quanta.enum("RandType", "ALONE")

local Dropor = singleton()
function Dropor:__init()
end

--执行掉落
function Dropor:execute(drop_id, drop_items)
    local group = drop_db:find_group(drop_id)
    if not group then
        return false
    end
    local rand = Random()
    for _, conf in pairs(group) do
        if conf.type == ALONE then
            rand:add_alone(conf.items, conf.rate)
        else
            rand:add_wheel(conf.items, conf.rate)
        end
    end
    local rand_items = rand:execute()
    if not rand_items then
        return false
    end
    for _, items in pairs(rand_items) do
        for item_id, num in pairs(items) do
            local onum = drop_items[item_id] or 0
            drop_items[item_id] = onum + num
        end
    end
    return true
end

quanta.dropor = Dropor()

return Dropor
