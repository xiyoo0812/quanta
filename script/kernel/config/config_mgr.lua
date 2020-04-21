--cfg_mgr.lua
local Listener              = import("common/listener.lua")
local ConfigTable           = import("share/core/config_table.lua")

local log_err               = logger.err
local tunpack               = table.unpack

-- 配置管理器
local ConfigMgr = singleton(Listener)
function ConfigMgr:__init()
    -- 配置对象列表
    self.config_list = {}
end

-- 初始化配置
function ConfigMgr:setup(confs)
    for _, args in pairs(confs) do
        self:load_table(tunpack(args))
    end
end

-- 添加一个配置
function ConfigMgr:load_table(tab_name, ...)
    local cfg_table = ConfigTable(tab_name, ...)
    self.config_list[tab_name] = cfg_table
    cfg_table:load_table()
end

-- 加载配置
function ConfigMgr:load_cfg(tab_name, cfg_data, version)
    local cfg_table = self:get_cfg_table(tab_name)
    if not cfg_table then
        log_err("[ConfigMgr][load_cfg] cfg_table = nil, tab_name=%s", tab_name)
        return
    end

    cfg_table:set_version(version)
    for _, v in pairs(cfg_data) do
        cfg_table:upsert(v)
    end
end

-- 获取一个cfg_table
function ConfigMgr:get_table(tab_name)
    return self.config_list[tab_name]
end

-- 获取item
function ConfigMgr:find_one(tab_name, ...)
    local cfg_table = self.config_list[tab_name]
    if cfg_table then
        return cfg_table:find_one(...)
    end
end

-- 获取items
function ConfigMgr:select(tab_name, ...)
    local cfg_table = self.config_list[tab_name]
    if cfg_table then
        return cfg_table:select(...)
    end
end

-- 获取版本
function ConfigMgr:get_version(tab_name)
    local cfg_table = self.config_list[tab_name]
    if cfg_table then
        return cfg_table:get_version()
    end
end

-- export
hive.config_mgr = ConfigMgr()
return ConfigMgr
