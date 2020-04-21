--cfg_table.lua
local tinsert       = table.insert
local log_err       = logger.err
local serialize     = logger.serialize
local tunpack       = table.unpack

local ConfigTable = class()
local prop = property(ConfigTable)
prop:reader("name", "")
prop:reader("keys", {})
prop:reader("data", {})
prop:reader("indexs", {})
prop:accessor("version", "")

-- 初始化一个配置表，...代表key，最多支持三个
function ConfigTable:__init(cfg_name, ...)
    self.name = cfg_name
    self.keys = {...}

    local key_len = #self.keys
    if key_len < 1 or key_len > 3 then
        log_err("[ConfigTable][init_table] keys len illegal. cfg_name=%s, len=%s", cfg_name, key_len)
        return
    end
end

function ConfigTable:load_cfg()
    import("config/" .. self:get_name() .. ".lua")
end

-- 查询map中的索引
function ConfigTable:get_data_idx(...)
    local vals = {...}
    local vals_len = #vals

    if vals_len == 0 then
        return
    end

    local map_idx = vals[1]
    for i = 2, vals_len, 1 do
        map_idx = map_idx .. "_" .. vals[i]
    end

    return self.indexs[map_idx], map_idx
end

-- 更新一行配置表
function ConfigTable:upsert(row)
    --print("[ConfigTable][upsert] cfg_name:", self.cfg_name, serialize(row))
    -- 检查row的key
    local key_len = #self.keys
    local t_key_val = {}
    for key_idx = 1, key_len, 1 do
        local tmp_key = self.keys[key_idx]
        t_key_val[key_idx] = row[tmp_key]
        if t_key_val[key_idx] == nil then
            log_err("[ConfigTable][upsert] row data config key not exist. row=%s, keys=%s", serialize(row), serialize(self.keys))
            return
        end
    end

    -- 查询map中的索引
    local data_idx, map_idx = self:get_data_idx(tunpack(t_key_val))
    if data_idx then
        -- map中找到，旧数据，之间更新data
        self.data[data_idx] = row
    elseif map_idx then
        -- map中找不到，新数据，insetdata，map更新
        tinsert(self.data, row)
        self.indexs[map_idx] = #self.data
    end
end

-- 获取一项，
-- 参数val1, val2, val3，必须与初始化key对应。
function ConfigTable:find_one(...)
    local data_idx = self:get_data_idx(...)
    if not data_idx then
        return
    end

    return self.data[data_idx]
end

-- 获取所有项，参数（field1,val1,field2,val2,field3,val3)，与初始化key无关
function ConfigTable:select(...)
    local paras = {...}
    local pa_len = #paras
    if pa_len % 2 ~= 0 then
        log_err("[ConfigTable][select] pa_len%2 != 0")
        return
    end

    local ret = {}
    for _, item in pairs(self.data) do
        for i = 1, pa_len, 2 do
            if item[paras[i]] ~= paras[i+1] then
                goto continue
            end
        end
        tinsert(ret, item)

        ::continue::
    end

    return ret
end

return ConfigTable