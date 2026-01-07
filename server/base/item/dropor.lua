--dropor.lua
--道具掉落器
local pairs         = pairs

local config_mgr    = quanta.get("config_mgr")
local drop_db       = config_mgr:init_table("drop", "id")

local Random        = import("basic/random.lua")

local ALONE         = quanta.enum("RandType", "ALONE")
local WHEEL         = quanta.enum("RandType", "WHEEL")

local Dropor = singleton()
function Dropor:__init()
    drop_db:add_group("group")
end

--将掉落合并到drop_items中
function Dropor:merge_items(drop_items, items)
    if items then
        for _, item in pairs(items) do
            for item_id, num in pairs(item) do
                local onum = drop_items[item_id] or 0
                drop_items[item_id] = onum + num
            end
        end
    end
end

--执行独立掉落
function Dropor:execute_alone(group, drop_items)
    local alone_rand = Random()
    for _, conf in pairs(group) do
        if conf.type == ALONE then
            alone_rand:add_alone(conf.items, conf.rate)
        end
    end

    local alone_items = alone_rand:execute()
    self:merge_items(drop_items, alone_items)
end

--执行轮盘掉落
function Dropor:execute_wheel(group, drop_items)
    -- 多个轮盘
    local wheel_rands = {}
    for _, conf in pairs(group) do
        local sub_group = conf.sub_group or 1
        if conf.type == WHEEL then
            if not wheel_rands[sub_group] then
                wheel_rands[sub_group] = Random()
            end
            wheel_rands[sub_group]:add_wheel(conf.items, conf.rate)
        end
    end
    for _,wheel_rand in pairs(wheel_rands) do
        local wheel_items = wheel_rand:execute()
        self:merge_items(drop_items, wheel_items)
    end
end

--执行掉落
function Dropor:execute(drop_id, drop_items)
    local group = drop_db:find_group(drop_id)
    if not group then
        return false
    end
    self:execute_alone(group, drop_items)
    self:execute_wheel(group, drop_items)
    if next(drop_items) then
        return true
    end
    return false
end

quanta.dropor = Dropor()

return Dropor
