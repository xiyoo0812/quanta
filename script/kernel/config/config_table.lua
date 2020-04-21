--cfg_table.lua
local tinsert       = table.insert
local tconcat       = table.concat
local log_err       = logger.err
local serialize     = logger.serialize

local TABLE_MAX_INDEX = 3

local ConfigTable = class()
local prop = property(ConfigTable)
prop:reader("name", nil)
prop:reader("rows", {})
prop:reader("indexs", {})
prop:accessor("version", 0)

-- 初始化一个配置表，indexs最多支持三个
function ConfigTable:__init(tab_name, indexs)
    local size = #indexs
    if size <= 0 and size >= TABLE_MAX_INDEX then
        self.name = tab_name
        self.indexs = indexs
        import("config/" .. self.name .. ".lua")
    else
        log_err("[ConfigTable][init_table] keys len illegal. tab_name=%s, size=%s", tab_name, size)
    end
end

-- 更新一行配置表
function ConfigTable:upsert(row)
    if not self.name then
        return
    end
    local row_indexs = {}
    for _, index in ipairs(self.indexs) do
        tinsert(row_indexs, row[index])
    end
    if #row_indexs ~= #self.indexs then
        log_err("[ConfigTable][upsert] row data index lost. row=%s, indexs=%s", serialize(row), serialize(self.indexs))
        return
    end
    local row_index = tconcat(indexs, "_")
    if row_index then
        self.rows[row_index] = row
    end
end

-- 获取一项，
-- query{ val1, val2, val3}，必须与初始化index对应。
function ConfigTable:find_one(query)
    local row_index = tconcat(query, "_")
    if row_index then
        return self.rows[row_index]
    end
end

-- 获取所有项，参数{field1=val1,field2=val2,field3=val3}，与初始化index无关
function ConfigTable:select(query)
    local rows = {}
    for _, row in pairs(self.rows) do
        for field, value in pairs(query or {}) do
            if row[field] ~= value then
                goto continue
            end
        end
        tinsert(rows, row)
        ::continue::
    end
    return rows
end

return ConfigTable
