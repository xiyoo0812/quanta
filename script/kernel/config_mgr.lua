--config_mgr.lua
local log_warn  = logger.warn

-- 配置管理器
local Config    = import("feature/config.lua")

local ConfigMgr = singleton()
function ConfigMgr:__init()
    -- 配置对象列表
    self.table_list = {}
end

--加载配置表并生成枚举
function ConfigMgr:init_enum_table(name, ename, main_key, ...)
    local conf_tab = self.table_list[name]
    if not conf_tab then
        conf_tab = self:create_table(name)
        conf_tab:setup(name, main_key, ...)
        local enum_obj = enum(ename, 0)
        for _, conf in conf_tab:iterator() do
            enum_obj[conf["enum_key"]] = conf[main_key]
        end
    end
    return conf_tab
end

--加载配置表并合并
function ConfigMgr:init_merge_table(name, merge_name, ...)
    local conf_tab = self.table_list[name]
    if conf_tab then
        return conf_tab
    end
    local merge_tab = self.table_list[merge_name]
    if not merge_tab then
        merge_tab = self:create_table(merge_name)
    end
    self.table_list[name] = merge_tab
    merge_tab:setup(name, ...)
    return merge_tab
end

-- 初始化配置表
function ConfigMgr:init_table(name, ...)
    local conf_tab = self.table_list[name]
    if not conf_tab then
        conf_tab = self:create_table(name)
        conf_tab:setup(name, ...)
    end
    return conf_tab
end

function ConfigMgr:create_table(name)
    local conf_tab = Config()
    self.table_list[name] = conf_tab
    conf_tab:set_name(name)
    return conf_tab
end

-- 获取配置表
function ConfigMgr:get_table(name)
    local conf_tab = self.table_list[name]
    if not conf_tab then
        log_warn("[ConfigMgr][get_table] table {} not init.", name)
    end
    return conf_tab
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

-- 获取配置表一条记录的key值
function ConfigMgr:find_value(name, key, ...)
    local conf_tab = self.table_list[name]
    if conf_tab then
        return conf_tab:find_value(key, ...)
    end
end

-- 获取配置表一条记录的key值
function ConfigMgr:find_number(name, key, ...)
    local conf_tab = self.table_list[name]
    if conf_tab then
        return conf_tab:find_number(key, ...)
    end
end

-- 获取配置表一条记录的key值
function ConfigMgr:find_integer(name, key, ...)
    local conf_tab = self.table_list[name]
    if conf_tab then
        return conf_tab:find_integer(key, ...)
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
