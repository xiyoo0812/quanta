-- mysql_test.lua
local log_info  = logger.info
local serialize = logger.serialize

local DBGroup   = enum("DBGroup")

local timer_mgr = quanta.get("timer_mgr")

local MysqlMgr = import("kernel/store/mysql_mgr.lua")
local mysql_mgr = MysqlMgr(DBGroup.AREA)


timer_mgr:once(3000, function()
    local code, res = mysql_mgr:create_table(2, "test_mysql", {pid = "VARCHAR(20)", value = "int"})
    log_info("crate_table code: %s, err = %s", code, serialize(res))
    --[[
    local icode, ierr = mysql_mgr:count(2, "test_mysql_1", {pid = 123456})
    log_info("db count code: %s, err = %s", icode, serialize(ierr))
    icode, ierr = mysql_mgr:insert(2, "test_mysql_1", {pid = 123456, data = {a =1, b=2}})
    log_info("db insert code: %s, err = %s", icode, serialize(ierr))
    icode, ierr = mysql_mgr:insert(2, "test_mysql_1", {pid = 123457, data = {a =1, b=2}})
    log_info("db insert code: %s, err = %s", icode, serialize(ierr))
    local fcode, res = mysql_mgr:find(2, "test_mysql_1", {}, {_id = 0})
    log_info("db find code: %s, res = %s", fcode, serialize(res))
    local f1code, f1res = mysql_mgr:find_one(2, "test_mysql_1", {pid = 123456}, {_id = 0})
    log_info("db find code: %s, res = %s", f1code, serialize(f1res))
    local ucode, uerr = mysql_mgr:update(2, "test_mysql_1", {pid = 123458, data = {a =1, b=4}}, {pid = 123457})
    log_info("db update code: %s, err = %s", ucode, uerr)
    icode, ierr = mysql_mgr:count(2, "test_mysql_1", {pid = 123456})
    log_info("db count code: %s, err = %s", icode, serialize(ierr))
]]
end)