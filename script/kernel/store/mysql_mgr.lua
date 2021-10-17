--mysql_mgr.lua

local KernCode      = enum("KernCode")
local SUCCESS       = KernCode.SUCCESS
local MYSQL_FAILED  = KernCode.MYSQL_FAILED

local event_mgr     = quanta.get("event_mgr")
local config_mgr    = quanta.get("config_mgr")

local MysqlMgr = class()
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
    local database = config_mgr:init_table("database", "db")
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
    if db_name and db_name ~= "default" then
        return self.mysql_dbs[db_name]
    end
    return self.default_db
end

function MysqlMgr:execute(db_name, sql)
    local mysqldb = self:get_db(db_name)
    if mysqldb then
        local ok, res_oe = mysqldb:query(sql)
        return ok and SUCCESS or MYSQL_FAILED, res_oe
    end
    return MYSQL_FAILED, "mysql db not exist"
end

return MysqlMgr
