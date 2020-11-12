--cfg_mgr.lua
local tunpack   = table.unpack

-- 配置管理器
local ConfigTable = import("basic/config/config_table.lua")
local ConfigMgr = singleton()
function ConfigMgr:__init()
    -- 配置对象列表
    self.table_list = {}
end

--加载配置表并生成枚举
function ConfigMgr:init_enum_table(name, indexs, enums)
    local conf_tab = self:init_table(name, tunpack(indexs))
    if conf_tab then
        local ename = enums[1]
        local enumfield = enums[3] or "id"
        local enumkey = enums[2] or "enum_key"
        local enum_obj = enum(ename, 0)
        for _, conf in conf_tab:iterator() do
            enum_obj[conf[enumkey]] = conf[enumfield]
        end
    end
    return conf_tab
end

-- 初始化配置表
function ConfigMgr:init_table(name, ...)
    local conf_tab = self.table_list[name]
    if not conf_tab then
        conf_tab = ConfigTable()
        self.table_list[name] = conf_tab
        conf_tab:setup(name, ...)
    end
    return conf_tab
end

-- 获取配置表
function ConfigMgr:get_table(name)
    return self.table_list[name]
end

-- 获取配置表一条记录
function ConfigMgr:find_one(name, ...)
    local conf_tab = self.table_list[name]
    if conf_tab then
        return conf_tab:find_one(...)
    end
end

-- 筛选配置表记录
function ConfigMgr:select(name, query)
    local conf_tab = self.table_list[name]
    if conf_tab then
        return conf_tab:select(query)
    end
end

-- export
quanta.config_mgr = ConfigMgr()
return ConfigMgr
