--cfg_mgr.lua
local ConfigTable   = import("basic/config/config_table.lua")

-- 配置管理器
local ConfigMgr = singleton()
function ConfigMgr:__init()
    -- 配置对象列表
    self.table_list = {}
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

--根据配置表生成枚举
function ConfigMgr:build_enum(tname, ename, key, value)
    local conf_tab = self.table_list[tname]
    if conf_tab then
        local enum_obj = enum(ename, 0)
        for _, conf in conf_tab:iterator() do
            enum_obj[conf[key]] = conf[value]
        end
    end
end

-- export
quanta.config_mgr = ConfigMgr()
return ConfigMgr
