--cfg_mgr.lua

-- 配置管理器
local ConfigTable = import("kernel/object/config_table.lua")
local ConfigMgr = singleton()
function ConfigMgr:__init()
    -- 配置对象列表
    self.table_list = {}
end

--加载配置表并生成枚举
function ConfigMgr:init_enum_table(name, ename, main_key, ...)
    local conf_tab = self:init_table(name, main_key, ...)
    if conf_tab then
        local enum_obj = enum(ename, 0)
        for _, conf in conf_tab:iterator() do
            enum_obj[conf["enum_key"]] = conf[main_key]
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

-- 关闭配置表
function ConfigMgr:close_table(name)
    self.table_list[name] = nil
end

-- 获取配置表一条记录
function ConfigMgr:find_one(name, ...)
    local conf_tab = self.table_list[name]
    if conf_tab then
        return conf_tab:find_one(...)
    end
end

-- 筛选配置表记录
function ConfigMgr:select(name, query, key)
    local conf_tab = self.table_list[name]
    if conf_tab then
        return conf_tab:select(query, key)
    end
end

-- export
quanta.config_mgr = ConfigMgr()
return ConfigMgr
