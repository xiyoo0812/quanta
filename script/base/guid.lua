--guid.lua
local type = type
local tonumber = tonumber
local otime = os.time
local ssub = string.sub
local sfind = string.find
local sformat = string.format
local mrandom = math.random

-- i - 世界号，10位，(0~1023)
-- g - 实体类型，10位 (0~1023)
-- s - 序号，14位 (0~16384)
-- ts - 时间戳，30位
local no_inedx_table = {}
local last_time = 0

-- 各位域的位数
local INDEX_BITS = 10
local GROUP_BITS = 10
local SNUM_BITS  = 14
--local TIME_BITS  = 30

-- 各位域的最大值
local MAX_INDEX = 1 << INDEX_BITS - 1  --1024 - 1
local MAX_GROUP = 1 << GROUP_BITS - 1  --1024 - 1
local MAX_SNUM  = 1 << SNUM_BITS  - 1  --16384 - 1
--local MAX_TIME  = 1 << TIME_BITS  - 1  --1073741824 - 1

local function new_guid_impl(index, group)
    group = group % MAX_GROUP
    index = index % MAX_INDEX
    -- 每一组index group独享一个id生成种子
    local table_index = index << INDEX_BITS | group
    if not no_inedx_table[table_index] then
        no_inedx_table[table_index] = 0
    end

    local now_time = otime()

    -- 秒切换以后时钟清零
    if now_time > last_time then
        no_inedx_table[table_index] = 0
        last_time = now_time
    else
        no_inedx_table[table_index] = no_inedx_table[table_index] + 1
        -- 种子溢出以后，时钟往前推
        if no_inedx_table[table_index] >= MAX_SNUM then
            no_inedx_table[table_index] = 0
            now_time = now_time + 1
            last_time = now_time
        end
    end

    -- 基准时钟：2019-01-1 00:00:00
    return ((last_time - 1546272000) << (SNUM_BITS + GROUP_BITS + INDEX_BITS)) |
        (no_inedx_table[table_index] << (GROUP_BITS + INDEX_BITS)) |
        (index << GROUP_BITS) | group
end

guid = {}
guid.new = function(index, group)
    return new_guid_impl(index or mrandom(0, MAX_INDEX), group or mrandom(0, MAX_GROUP))
end

guid.string = function(index, group)
    local num = new_guid_impl(index or mrandom(0, MAX_INDEX), group or mrandom(0, MAX_GROUP))
    return sformat("0x%x", num)
end

guid.tostring = function(guid)
    return sformat("0x%x", guid)
end

guid.number = function(str)
    local i, j = sfind(str, "0x")
    if i and j then
        return tonumber(ssub(str, j + 1), 16)
    end
    return 0
end

guid.group = function(guid)
    if type(guid) == "string" then
        local i, j = sfind(guid, "0x")
        if not i then
            return 0
        end
        guid = tonumber(ssub(guid, j + 1), 16)
    end
    return guid & 0x3ff
end

guid.index = function(guid)
    if type(guid) == "string" then
        local i, j = sfind(guid, "0x")
        if not i then
            return 0
        end
        guid = tonumber(ssub(guid, j + 1), 16)
    end
    return (guid >> GROUP_BITS) & 0x3ff
end

guid.group_index = function(guid)
    if type(guid) == "string" then
        local i, j = sfind(guid, "0x")
        if not i then
            return 0
        end
        guid = tonumber(ssub(guid, j + 1), 16)
    end
    return guid & 0x3ff, (guid >> GROUP_BITS) & 0x3ff
end

guid.room_group = function(rtype, mode)
    return rtype << 4 | mode
end

guid.room_type = function(group)
    return (group >> 4) & 0xf
end

guid.room_mode = function(group)
    return group & 0xf
end

--local a, ant = guid.new(1023, 255)
--local as = guid.string(a)
--local an = guid.tostring(as)
--local t = guid.group(a)
--local w = guid.index(a)
--print(a, ant, as, an, w, t)
--local test_table = {}
--for n = 0, 10000000 do
--    local id = new_guid(35, 47)
--    if not test_table[id] then
--        test_table[id] = id
--        --print(id)
--    else
--        print("error")
--    end
--  --if 0 == (n % 100000) then
--  --    print(n)
--  --    print(os.time())
--  --end
--end

