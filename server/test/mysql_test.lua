-- mysql_test.lua
local log_debug = logger.debug

local DBGroup   = enum("DBGroup")

local timer_mgr = quanta.get("timer_mgr")

local MysqlMgr = import("kernel/store/mysql_mgr.lua")
local mysql_mgr = MysqlMgr(DBGroup.AREA)


timer_mgr:once(3000, function()
    local ccode, count_oe = mysql_mgr:count(2, "test_mysql", {pid = "123456"})
    log_debug("db count code: %s, count = %s", ccode, count_oe)
    local ucode, uerr = mysql_mgr:update(2, "test_mysql", {pid = "123456", value = 40}, {pid = "123457"})
    log_debug("db update code: %s, err = %s", ucode, uerr)
    local fcode, fres = mysql_mgr:find_one(2, "test_mysql", {pid = "123456"}, { _id = 0})
    log_debug("db find code: %s, res = %s", fcode, fres)
    local ccode2, count_oe2 = mysql_mgr:count(2, "test_mysql", {pid = "123456"})
    log_debug("db count code: %s, count = %s", ccode2, count_oe2)
    --[[
    local code, res = mysql_mgr:create_table(2, "test_mysql", {pid = "VARCHAR(20)", value = "int"})
    log_debug("crate_table code: %s, err = %s", code, res)
    icode, ierr = mysql_mgr:insert(2, "test_mysql", {pid = "123456", value = 20})
    log_debug("db insert code: %s, err = %s", icode, ierr)
    local icode, ierr = mysql_mgr:insert(2, "test_mysql", {pid = "123456", value = 21})
    log_debug("db insert code: %s, err = %s", icode, ierr)
    icode, ierr = mysql_mgr:insert(2, "test_mysql", {pid = "123457", value = 30})
    log_debug("db insert code: %s, err = %s", icode, ierr)
    local ucode, uerr = mysql_mgr:update(2, "test_mysql", {pid = "123458", value = 40}, {pid = "123457"})
    log_debug("db update code: %s, err = %s", ucode, uerr)
    local dcode, derr = mysql_mgr:delete(2, "test_mysql", {pid = "123456"}, true)
    log_debug("db delete code: %s, err = %s", dcode, derr)
    dcode, derr = mysql_mgr:delete(2, "test_mysql", {pid = "123458"})
    log_debug("db delete code: %s, err = %s", dcode, derr)
    ]]
    --[[
    local icode, ierr = mysql_mgr:count(2, "test_mysql_1", {pid = 123456})
    log_debug("db count code: %s, err = %s", icode, ierr)
    icode, ierr = mysql_mgr:insert(2, "test_mysql_1", {pid = 123456, data = {a =1, b=2}})
    log_debug("db insert code: %s, err = %s", icode, ierr)
    icode, ierr = mysql_mgr:insert(2, "test_mysql_1", {pid = 123457, data = {a =1, b=2}})
    log_debug("db insert code: %s, err = %s", icode, ierr)
    local fcode, res = mysql_mgr:find(2, "test_mysql_1", {}, {_id = 0})
    log_debug("db find code: %s, res = %s", fcode, res)
    local f1code, f1res = mysql_mgr:find_one(2, "test_mysql_1", {pid = 123456}, {_id = 0})
    log_debug("db find code: %s, res = %s", f1code, f1res)
    local ucode, uerr = mysql_mgr:update(2, "test_mysql_1", {pid = 123458, data = {a =1, b=4}}, {pid = 123457})
    log_debug("db update code: %s, err = %s", ucode, uerr)
    icode, ierr = mysql_mgr:count(2, "test_mysql_1", {pid = 123456})
    log_debug("db count code: %s, err = %s", icode, ierr)
]]
end)