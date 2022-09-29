--mysql_mgr.lua
local log_err       = logger.err

local event_mgr     = quanta.get("event_mgr")
local config_mgr    = quanta.get("config_mgr")

local SUCCESS       = quanta.enum("KernCode", "SUCCESS")
local MYSQL_FAILED  = quanta.enum("KernCode", "MYSQL_FAILED")

local MysqlMgr = singleton()
local prop = property(MysqlMgr)
prop:reader("mysql_dbs", {})    -- mysql_dbs
prop:reader("default_db", nil)  -- default_db
prop:reader("default_id", nil)  -- default_id

function MysqlMgr:__init()
    self:setup()
    -- 注册事件
    event_mgr:add_listener(self, "rpc_mysql_execute", "execute")
end

--初始化
function MysqlMgr:setup()
    local MysqlDB = import("driver/mysql.lua")
    local database = config_mgr:init_table("database", "db", "driver")
    for _, conf in database:iterator() do
        if conf.driver == "mysql" then
            local mysql_db = MysqlDB(conf)
            self.mysql_dbs[conf.id] = mysql_db
            if conf.default then
                self.default_id = conf.id
                self.default_db = mysql_db
            end
        end
    end
    config_mgr:close_table("database")
end

--查找mysql db
function MysqlMgr:get_db(db_id)
    if not db_id or db_id == self.default_id then
        return self.default_db
    end
    return self.mysql_dbs[db_id]
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
