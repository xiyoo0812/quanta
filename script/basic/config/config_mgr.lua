--cfg_mgr.lua
local ConfigTable   = import("basic/config/config_table.lua")

local tunpack       = table.unpack

-- 配置管理器
local ConfigMgr = singleton()
function ConfigMgr:__init()
    -- 配置对象列表
    self.table_list = {}
end

-- 初始化配置表
function ConfigMgr:init_table(name, ...)
    local conf_tab = ConfigTable()
    self.table_list[name] = conf_tab
    conf_tab:setup(name, ...)
    return conf_tab
end

-- 获取配置表
function ConfigMgr:get_table(name)
    return self.table_list[name]
end

-- 获取配置表一条记录
function ConfigMgr:find_one(name, query)
    local conf_tab = self.table_list[name]
    if conf_tab then
        return conf_tab:find_one(query)
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
