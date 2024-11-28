--mysql_mgr.lua
local log_err       = logger.err

local event_mgr     = quanta.get("event_mgr")

local SUCCESS       = quanta.enum("KernCode", "SUCCESS")
local MYSQL_FAILED  = quanta.enum("KernCode", "MYSQL_FAILED")

local MysqlMgr = singleton()
local prop = property(MysqlMgr)
prop:reader("mysql_db", nil)    --mysql_db

function MysqlMgr:__init()
    self:setup()
    -- 注册事件
    event_mgr:add_listener(self, "rpc_mysql_query", "query")
    event_mgr:add_listener(self, "rpc_mysql_prepare", "prepare")
    event_mgr:add_listener(self, "rpc_mysql_execute", "execute")
end

--初始化
function MysqlMgr:setup()
    local MysqlDB = import("driver/mysql.lua")
    local driver = environ.driver("QUANTA_MYSQL_URL")
    self.mysql_db = MysqlDB(driver)
end

function MysqlMgr:query(primary_id, sql)
    local mysqldb = self.mysql_db
    if mysqldb and mysqldb:set_executer(primary_id) then
        local ok, res_oe = mysqldb:query(sql)
        if not ok then
            log_err("[MysqlMgr][query] query {} failed, because: {}", sql, res_oe)
        end
        return ok and SUCCESS or MYSQL_FAILED, res_oe
    end
    return MYSQL_FAILED, "mysql db not exist"
end

function MysqlMgr:execute(primary_id, stmt, ...)
    local mysqldb = self.mysql_db
    if mysqldb and mysqldb:set_executer(primary_id) then
        local ok, res_oe = mysqldb:execute(stmt, ...)
        if not ok then
            log_err("[MysqlMgr][execute] execute {} failed, because: {}", stmt, res_oe)
        end
        return ok and SUCCESS or MYSQL_FAILED, res_oe
    end
    return MYSQL_FAILED, "mysql db not exist"
end

function MysqlMgr:prepare(stmt, sql)
    local mysqldb = self.mysql_db
    if mysqldb and mysqldb:set_executer() then
        local ok, res_oe = mysqldb:prepare(stmt, sql)
        if not ok then
            log_err("[MysqlMgr][prepare] prepare {} failed, because: {}", sql, res_oe)
        end
        return ok and SUCCESS or MYSQL_FAILED, res_oe
    end
    return MYSQL_FAILED, "mysql db not exist"
end

quanta.mysql_mgr = MysqlMgr()

return MysqlMgr
