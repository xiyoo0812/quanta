-- mysql_test.lua
local log_debug = logger.debug

local timer_mgr = quanta.get("timer_mgr")

local MysqlMgr = import("kernel/store/mysql_mgr.lua")
local mysql_mgr = MysqlMgr()

timer_mgr:once(3000, function()
    local ccode, count_oe = mysql_mgr:execute("default", "select count(*) from test_mysql where pid=123456")
    log_debug("db count code: %s, count = %s", ccode, count_oe)
    local ucode, uerr = mysql_mgr:execute("default", "update test_mysql set pid = 123456, value = 40 where pid = 123457")
    log_debug("db update code: %s, err = %s", ucode, uerr)
    local fcode, fres = mysql_mgr:execute("default", "select * from test_mysql where pid = 123456")
    log_debug("db find code: %s, res = %s", fcode, fres)
    local ccode2, count_oe2 = mysql_mgr:execute("default", "select count(*) from test_mysql where pid=123456")
    log_debug("db count code: %s, count = %s", ccode2, count_oe2)
   --[[
    local code, res = mysql_mgr:create_table("default", "test_mysql", {pid = "VARCHAR(20)", value = "int"})
    log_debug("crate_table code: %s, err = %s", code, res)
    icode, ierr = mysql_mgr:insert("default", "test_mysql", {pid = "123456", value = 20})
    log_debug("db insert code: %s, err = %s", icode, ierr)
    local icode, ierr = mysql_mgr:insert("default", "test_mysql", {pid = "123456", value = 21})
    log_debug("db insert code: %s, err = %s", icode, ierr)
    icode, ierr = mysql_mgr:insert("default", "test_mysql", {pid = "123457", value = 30})
    log_debug("db insert code: %s, err = %s", icode, ierr)
    local ucode, uerr = mysql_mgr:update("default", "test_mysql", {pid = "123458", value = 40}, {pid = "123457"})
    log_debug("db update code: %s, err = %s", ucode, uerr)
    local dcode, derr = mysql_mgr:delete("default", "test_mysql", {pid = "123456"}, true)
    log_debug("db delete code: %s, err = %s", dcode, derr)
    dcode, derr = mysql_mgr:delete("default", "test_mysql", {pid = "123458"})
    log_debug("db delete code: %s, err = %s", dcode, derr)
    ]]
end)