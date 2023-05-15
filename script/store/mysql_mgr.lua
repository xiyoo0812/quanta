--mysql_mgr.lua
local log_err       = logger.err

local event_mgr     = quanta.get("event_mgr")

local SUCCESS       = quanta.enum("KernCode", "SUCCESS")
local MYSQL_FAILED  = quanta.enum("KernCode", "MYSQL_FAILED")

local MAIN_DBID     = environ.number("QUANTA_DB_MAIN_ID")

local MysqlMgr = singleton()
local prop = property(MysqlMgr)
prop:reader("mysql_dbs", {})    -- mysql_dbs

function MysqlMgr:__init()
    self:setup()
    -- 注册事件
    event_mgr:add_listener(self, "rpc_mysql_execute", "execute")
end

--初始化
function MysqlMgr:setup()
    local MysqlDB = import("driver/mysql.lua")
    local drivers = environ.driver("QUANTA_MYSQL_URLS")
    for i, conf in ipairs(drivers) do
        local mysql_db = MysqlDB(conf, i)
        self.mysql_dbs[conf.id] = mysql_db
    end
end

--查找mysql db
function MysqlMgr:get_db(db_id)
    return self.mysql_dbs[db_id or MAIN_DBID]
end

function MysqlMgr:execute(db_id, sql)
    local mysqldb = self:get_db(db_id)
    if mysqldb then
        local ok, res_oe = mysqldb:query(sql)
        if not ok then
            log_err("[MysqlMgr][execute] execute %s failed, because: %s", sql, res_oe)
        end
        return ok and SUCCESS or MYSQL_FAILED, res_oe
    end
    return MYSQL_FAILED, "mysql db not exist"
end

quanta.mysql_mgr = MysqlMgr()

return MysqlMgr
