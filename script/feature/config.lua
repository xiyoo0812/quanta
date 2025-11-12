--cfg_table.lua
local next          = next
local pairs         = pairs
local ipairs        = ipairs
local select        = select
local tonumber      = tonumber
local log_err       = logger.err
local log_warn      = logger.warn
local tconcat       = table.concat
local tinsert       = table.insert
local tunpack       = table.unpack
local qtcopy        = table.copy
local sformat       = string.format
local tointeger     = math.tointeger

local event_mgr     = quanta.get("event_mgr")

local TABLE_MAX_INDEX = 3

local ConfigTable = class()
local prop = property(ConfigTable)
prop:reader("rows", {})
prop:reader("groups", {})
prop:reader("count", 0)
prop:reader("indexs", nil)
prop:reader("group_key", nil)
prop:reader("initial", false)
prop:accessor("name", nil)

-- 初始化一个配置表，indexs最多支持三个
function ConfigTable:__init()
end

function ConfigTable:setup(name, ...)
    local size = select("#", ...)
    if size > 0 and size <= TABLE_MAX_INDEX then
        self.indexs = {...}
        import(sformat("config/%s_cfg.lua", name))
    else
        log_err("[ConfigTable][setup] keys len illegal. name={}, size={}", name, size)
    end
end

-- 更新一行配置表
function ConfigTable:upsert(row)
    if not self.indexs then
        return
    end
    local row_indexs = {}
    for _, index in ipairs(self.indexs) do
        tinsert(row_indexs, row[index])
    end
    if #row_indexs ~= #self.indexs then
        log_err("[ConfigTable][upsert] table {} row index lost. row={}, indexs={}", self.name, row, self.indexs)
        return
    end
    local row_index = self:build_index(tunpack(row_indexs))
    if row_index then
        row.version = self.version
        local raw_row = self.rows[row_index]
        if raw_row then
            qtcopy(row, raw_row)
        else
            self.count = self.count + 1
            self.rows[row_index] = row
        end
    end
end

--生成index
function ConfigTable:build_index(...)
    local n = select("#", ...)
    if n == 1 then
        return ...
    end
    if n > 0 then
        return tconcat({...}, "@@")
    end
end

-- 获取一项，
-- ...必须与初始化index对应。
function ConfigTable:find_one(...)
    local row_index = self:build_index(...)
    if not row_index then
        log_warn("[ConfigTable][find_one] table {} row index is nil.", self.name)
        return
    end
    local row = self.rows[row_index]
    if not row then
        log_warn("[ConfigTable][find_one] table {} row data not found. index={}", self.name, row_index)
    end
    return row
end

-- 获取一项的指定key值，
-- ...必须与初始化index对应。
function ConfigTable:find_value(key, ...)
    local row = self:find_one(...)
    if row then
        return row[key]
    end
end

-- 获取一项的指定key值，
-- ...必须与初始化index对应。
function ConfigTable:find_number(key, ...)
    local row = self:find_one(...)
    if row then
        return tonumber(row[key])
    end
end

-- 获取一项的指定key值，
-- ...必须与初始化index对应。
function ConfigTable:find_integer(key, ...)
    local row = self:find_one(...)
    if row then
        return tointeger(row[key])
    end
end

--设置分组数据
function ConfigTable:add_group(group_key, force)
    if self.groups[group_key] and (not force) then
        return
    end
    local group = {}
    for _, row in pairs(self.rows) do
        local row_key = row[group_key]
        if row_key then
            local datas = group[row_key]
            if not datas then
                group[row_key] = { row }
            else
                tinsert(datas, row)
            end
        end
    end
    if not self.group_key then
        self.group_key = group_key
    end
    self.groups[group_key] = group
end

--查询分组数据
function ConfigTable:find_group(key, gkey)
    local group_key = gkey or self.group_key
    local dgroup = self.groups[group_key]
    if not dgroup then
        log_warn("[ConfigTable][find_group] table {} group {} data empty.", self.name, group_key)
    end
    return dgroup[key]
end

--更新分组
function ConfigTable:update()
    if self.initial then
        for key in pairs(self.groups) do
            self:add_group(key, true)
        end
        event_mgr:notify_trigger(sformat("on_cfg_%s_changed", self.name))
    end
    self.initial = true
end

-- 获取所有项，参数{field1=val1,field2=val2,field3=val3}，与初始化index无关
function ConfigTable:select(query, key)
    local rows = {}
    for _, row in pairs(self.rows) do
        for field, value in pairs(query or {}) do
            if row[field] ~= value then
                goto continue
            end
        end
        if key then
            tinsert(rows, row[key])
        else
            tinsert(rows, row)
        end
        ::continue::
    end
    return rows
end

--迭代器
function ConfigTable:iterator()
    local index = nil
    local rows = self.rows
    local function iter()
        index = next(rows, index)
        if index then
            return index, rows[index]
        end
    end
    return iter
end

return ConfigTable
