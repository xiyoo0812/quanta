--influx_mgr.lua
local tpack         = table.pack
local log_err       = logger.err

local KernCode      = enum("KernCode")
local SUCCESS       = KernCode.SUCCESS
local REDIS_FAILED  = KernCode.REDIS_FAILED

local event_mgr     = quanta.get("event_mgr")
local config_mgr    = quanta.get("config_mgr")

local InfluxMgr = singleton()
local prop = property(InfluxMgr)
prop:accessor("influx_dbs", {})     -- influx_dbs
prop:accessor("default_db", nil)    -- default_db

function InfluxMgr:__init()
    self:setup()
    -- 注册事件
    event_mgr:add_listener(self, "influx_write", "write")
    event_mgr:add_listener(self, "influx_query", "query")
end

--初始化
function InfluxMgr:setup()
    local InfluxDB = import("driver/influx.lua")
    local database = config_mgr:init_table("database", "db", "driver")
    for _, conf in database:iterator() do
        if conf.driver == "influx" then
            local influx_db = InfluxDB(conf)
            self.influx_dbs[conf.db] = influx_db
            if conf.default then
                self.default_db = influx_db
            end
        end
    end
end

--查找influx db
function InfluxMgr:get_db(db_name)
    if not db_name or db_name == "default" then
        return self.default_db
    end
    return self.influx_dbs[db_name]
end

function InfluxMgr:query(db_name, script)
    local influxdb = self:get_db(db_name)
    if influxdb then
        local ok, res_oe = influxdb:query(script)
        if not ok then
            log_err("[InfluxMgr][query] query %s failed, because: %s", script, res_oe)
        end
        return ok and SUCCESS or REDIS_FAILED, res_oe
    end
    return REDIS_FAILED, "influx db not exist"
end

function InfluxMgr:write(db_name, tab_name, tags, fields)
    local influxdb = self:get_db(db_name)
    if influxdb then
        local ok, res_oe = influxdb:write(cmd, ...)
        if not ok then
            log_err("[InfluxMgr][write] write %s tags:%s,fields:%s  failed, because: %s", tab_name, tags, fields, res_oe)
        end
        return ok and SUCCESS or REDIS_FAILED, res_oe
    end
    return REDIS_FAILED, "influx db not exist"
end

quanta.influx_mgr = InfluxMgr()

return InfluxMgr
