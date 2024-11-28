--pgsql_mgr.lua
local log_err       = logger.err

local event_mgr     = quanta.get("event_mgr")

local SUCCESS       = quanta.enum("KernCode", "SUCCESS")
local PGSQL_FAILED  = quanta.enum("KernCode", "PGSQL_FAILED")

local PgsqlMgr = singleton()
local prop = property(PgsqlMgr)
prop:reader("pgsql_db", nil)    --pgsql_db

function PgsqlMgr:__init()
    self:setup()
    -- 注册事件
    event_mgr:add_listener(self, "rpc_pgsql_query", "query")
    event_mgr:add_listener(self, "rpc_pgsql_prepare", "prepare")
    event_mgr:add_listener(self, "rpc_pgsql_execute", "execute")
end

--初始化
function PgsqlMgr:setup()
    local PgsqlDB = import("driver/pgsql.lua")
    local driver = environ.driver("QUANTA_PGSQL_URL")
    self.pgsql_db = PgsqlDB(driver)
end

function PgsqlMgr:query(primary_id, sql)
    local pgsqldb = self.pgsql_db
    if pgsqldb and pgsqldb:set_executer(primary_id) then
        local ok, res_oe = pgsqldb:query(sql)
        if not ok then
            log_err("[PgsqlMgr][query] query {} failed, because: {}", sql, res_oe)
        end
        return ok and SUCCESS or PGSQL_FAILED, res_oe
    end
    return PGSQL_FAILED, "pgsql db not exist"
end

function PgsqlMgr:execute(primary_id, stmt, ...)
    local pgsqldb = self.pgsql_db
    if pgsqldb and pgsqldb:set_executer(primary_id) then
        local ok, res_oe = pgsqldb:execute(stmt, ...)
        if not ok then
            log_err("[PgsqlMgr][execute] execute {} failed, because: {}", stmt, res_oe)
        end
        return ok and SUCCESS or PGSQL_FAILED, res_oe
    end
    return PGSQL_FAILED, "pgsql db not exist"
end

function PgsqlMgr:prepare(stmt, sql)
    local pgsqldb = self.pgsql_db
    if pgsqldb and pgsqldb:set_executer() then
        local ok, res_oe = pgsqldb:prepare(stmt, sql)
        if not ok then
            log_err("[PgsqlMgr][prepare] prepare {} failed, because: {}", sql, res_oe)
        end
        return ok and SUCCESS or PGSQL_FAILED, res_oe
    end
    return PGSQL_FAILED, "pgsql db not exist"
end

quanta.pgsql_mgr = PgsqlMgr()

return PgsqlMgr
