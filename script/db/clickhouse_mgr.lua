--clickhouse_mgr.lua
local log_err       = logger.err

local event_mgr     = quanta.get("event_mgr")

local SUCCESS       = quanta.enum("KernCode", "SUCCESS")
local MYSQL_FAILED  = quanta.enum("KernCode", "MYSQL_FAILED")

local ClickHouseMgr = singleton()
local prop = property(ClickHouseMgr)
prop:reader("clickhouse_db", nil)   --clickhouse_db

function ClickHouseMgr:__init()
    self:setup()
    -- 注册事件
    event_mgr:add_listener(self, "rpc_clickhouse_query", "query")
end

--初始化
function ClickHouseMgr:setup()
    local MysqlDB = import("driver/mysql.lua")
    local driver = environ.driver("QUANTA_MYSQL_URL")
    self.clickhouse_db = MysqlDB(driver)
end

function ClickHouseMgr:query(primary_id, sql)
    local clickhouse_db = self.clickhouse_db
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
