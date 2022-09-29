--clickhouse_mgr.lua
local log_err       = logger.err

local event_mgr     = quanta.get("event_mgr")
local config_mgr    = quanta.get("config_mgr")

local SUCCESS       = quanta.enum("KernCode", "SUCCESS")
local MYSQL_FAILED  = quanta.enum("KernCode", "MYSQL_FAILED")

local ClickHouseMgr = singleton()
local prop = property(ClickHouseMgr)
prop:reader("clickhouse_dbs", {})   -- clickhouse_dbs
prop:reader("default_db", nil)      -- default_db
prop:reader("default_id", nil)      -- default_id

function ClickHouseMgr:__init()
    self:setup()
    -- 注册事件
    event_mgr:add_listener(self, "rpc_clickhouse_execute", "execute")
end

--初始化
function ClickHouseMgr:setup()
    local MysqlDB = import("driver/mysql.lua")
    local database = config_mgr:init_table("database", "db", "driver")
    for _, conf in database:iterator() do
        if conf.driver == "clickhouse" then
            local clickhouse_db = MysqlDB(conf)
            self.clickhouse_dbs[conf.id] = clickhouse_db
            if conf.default then
                self.default_id = conf.id
                self.default_db = clickhouse_db
            end
        end
    end
    config_mgr:close_table("database")
end

--查找clickhouse db
function ClickHouseMgr:get_db(db_id)
    if not db_id or db_id == self.default_id then
        return self.default_db
    end
    return self.clickhouse_dbs[db_id]
end

function ClickHouseMgr:execute(db_id, sql)
    local clickhousedb = self:get_db(db_id)
    if clickhousedb then
        local ok, res_oe = clickhousedb:query(sql)
        if not ok then
            log_err("[ClickHouseMgr][execute] execute %s failed, because: %s", sql, res_oe)
        end
        return ok and SUCCESS or MYSQL_FAILED, res_oe
    end
    return MYSQL_FAILED, "clickhouse db not exist"
end

quanta.clickhouse = ClickHouseMgr()

return ClickHouseMgr
