--mysql_mgr.lua
local hash_code     = utility.hash_code

local DBGroup       = enum("DBGroup")
local KernCode      = enum("KernCode")
local SUCCESS       = KernCode.SUCCESS
local MYSQL_FAILED  = KernCode.MYSQL_FAILED

local config_mgr    = quanta.get("config_mgr")

local MysqlMgr = class()
local prop = property(MysqlMgr)
prop:accessor("hash_mode", false)   -- hash_mode
prop:accessor("mysql_dbs", {})      -- mysql_dbs

function MysqlMgr:__init(group)
    self:setup(group)
    self.hash_mode = (group == DBGroup.HASH)
end

--初始化
function MysqlMgr:setup(group)
    local MysqlDB = import("driver/mysql.lua")
    local database = config_mgr:init_table("database", "group", "index", "driver")
    for _, conf in database:iterator() do
        if group == conf.group and conf.driver == "mysql" then
            self.mysql_dbs[conf.index] = MysqlDB(conf)
        end
    end
end

--查找mysql db
function MysqlMgr:get_db(index)
    if self.hash_mode then
        local hash_index = hash_code(index, #self.mysql_dbs)
        return self.mysql_dbs[hash_index]
    end
    return self.mysql_dbs[index]
end

function MysqlMgr:execute(index, sql)
    local mysqldb = self:get_db(index)
    if mysqldb then
        local ok, res_oe = mysqldb:query(sql)
        return ok and SUCCESS or MYSQL_FAILED, res_oe
    end
    return MYSQL_FAILED, "mysql db not exist"
end

return MysqlMgr
