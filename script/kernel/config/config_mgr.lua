--cfg_mgr.lua
local Listener              = import("common/listener.lua")
local ConfigTable           = import("share/core/config_table.lua")

local tunpack               = table.unpack

-- 配置管理器
local ConfigMgr = singleton(Listener)
function ConfigMgr:__init()
    -- 配置对象列表
    self.table_list = {}
end

-- 初始化配置
function ConfigMgr:setup(confs)
    for tab_name, indexs in pairs(confs) do
        self:init_table(tab_name, indexs)
    end
end

-- 添加一个配置
function ConfigMgr:init_table(tab_name, indexs)
    local conf_tab = ConfigTable(tab_name, indexs)
    self.table_list[tab_name] = conf_tab
end

-- 获取一个cfg_table
function ConfigMgr:get_table(tab_name)
    return self.table_list[tab_name]
end

-- 获取item
function ConfigMgr:find_one(tab_name, query)
    local cfg_table = self.table_list[tab_name]
    if cfg_table then
        return cfg_table:find_one(query)
    end
end

-- 获取items
function ConfigMgr:select(tab_name, query)
    local cfg_table = self.table_list[tab_name]
    if cfg_table then
        return cfg_table:select(query)
    end
end

-- 获取版本
function ConfigMgr:get_version(tab_name)
    local cfg_table = self.table_list[tab_name]
    if cfg_table then
        return cfg_table:get_version()
    end
end

-- export
hive.config_mgr = ConfigMgr()
return ConfigMgr
