--clickhouse_mgr.lua
local log_err       = logger.err

local event_mgr     = quanta.get("event_mgr")

local SUCCESS       = quanta.enum("KernCode", "SUCCESS")
local MYSQL_FAILED  = quanta.enum("KernCode", "MYSQL_FAILED")

local MAIN_DBID     = environ.number("QUANTA_DB_MAIN_ID")

local ClickHouseMgr = singleton()
local prop = property(ClickHouseMgr)
prop:reader("clickhouse_dbs", {})   -- clickhouse_dbs

function ClickHouseMgr:__init()
    self:setup()
    -- 注册事件
    event_mgr:add_listener(self, "rpc_clickhouse_query", "query")
end

--初始化
function ClickHouseMgr:setup()
    local MysqlDB = import("driver/mysql.lua")
    local drivers = environ.driver("QUANTA_MYSQL_URLS")
    for i, conf in ipairs(drivers) do
        local clickhouse_db = MysqlDB(conf, i)
        self.clickhouse_dbs[i] = clickhouse_db
    end
end

--查找clickhouse db
function ClickHouseMgr:get_db(db_id)
    return self.clickhouse_dbs[db_id or MAIN_DBID]
end

function ClickHouseMgr:query(db_id, primary_id, sql)
    local clickhouse_db = self:get_db(db_id)
    if clickhouse_db and clickhouse_db:set_executer(primary_id) then
        local ok, res_oe = clickhouse_db:query(sql)
        if not ok then
            log_err("[ClickHouseMgr][query] query {} failed, because: {}", sql, res_oe)
        end
        return ok and SUCCESS or MYSQL_FAILED, res_oe
    end
    return MYSQL_FAILED, "clickhouse db not exist"
end

quanta.clickhouse = ClickHouseMgr()

return ClickHouseMgr
