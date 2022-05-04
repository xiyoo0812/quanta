--mysql_mgr.lua
local log_err       = logger.err
local qget          = quanta.get
local qenum         = quanta.enum

local event_mgr     = qget("event_mgr")
local config_mgr    = qget("config_mgr")

local SUCCESS       = qenum("KernCode", "SUCCESS")
local MYSQL_FAILED  = qenum("KernCode", "MYSQL_FAILED")

local MysqlMgr = singleton()
local prop = property(MysqlMgr)
prop:accessor("mysql_dbs", {})      -- mysql_dbs
prop:accessor("default_db", nil)    -- default_db

function MysqlMgr:__init()
    self:setup()
    -- 注册事件
    event_mgr:add_listener(self, "mysql_execute", "execute")
end

--初始化
function MysqlMgr:setup()
    local MysqlDB = import("driver/mysql.lua")
    local database = config_mgr:init_table("database", "db", "driver")
    for _, conf in database:iterator() do
        if conf.driver == "mysql" then
            local mysql_db = MysqlDB(conf)
            self.mysql_dbs[conf.db] = mysql_db
            if conf.default then
                self.default_db = mysql_db
            end
        end
    end
end

--查找mysql db
function MysqlMgr:get_db(db_name)
    if not db_name or db_name == "default" then
        return self.default_db
    end
    return self.mysql_dbs[db_name]
end

function MysqlMgr:execute(db_name, sql)
    local mysqldb = self:get_db(db_name)
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
