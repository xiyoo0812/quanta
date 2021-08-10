-- mysql_test.lua
local log_info  = logger.info
local serialize = logger.serialize

local DBGroup   = enum("DBGroup")

local timer_mgr = quanta.get("timer_mgr")

local MysqlMgr = import("kernel/store/mysql_mgr.lua")
local mysql_mgr = MysqlMgr(DBGroup.AREA)


timer_mgr:once(3000, function()
    local ccode, count_oe = mysql_mgr:count(2, "test_mysql", {pid = "123456"})
    log_info("db count code: %s, count = %s", ccode, serialize(count_oe))
    local ucode, uerr = mysql_mgr:update(2, "test_mysql", {pid = "123456", value = 40}, {pid = "123457"})
    log_info("db update code: %s, err = %s", ucode, serialize(uerr))
    local fcode, fres = mysql_mgr:find_one(2, "test_mysql", {pid = "123456"}, { _id = 0})
    log_info("db find code: %s, res = %s", fcode, serialize(fres))
    local ccode2, count_oe2 = mysql_mgr:count(2, "test_mysql", {pid = "123456"})
    log_info("db count code: %s, count = %s", ccode2, serialize(count_oe2))
    --[[
    local code, res = mysql_mgr:create_table(2, "test_mysql", {pid = "VARCHAR(20)", value = "int"})
    log_info("crate_table code: %s, err = %s", code, serialize(res))
    icode, ierr = mysql_mgr:insert(2, "test_mysql", {pid = "123456", value = 20})
    log_info("db insert code: %s, err = %s", icode, serialize(ierr))
    local icode, ierr = mysql_mgr:insert(2, "test_mysql", {pid = "123456", value = 21})
    log_info("db insert code: %s, err = %s", icode, serialize(ierr))
    icode, ierr = mysql_mgr:insert(2, "test_mysql", {pid = "123457", value = 30})
    log_info("db insert code: %s, err = %s", icode, serialize(ierr))
    local ucode, uerr = mysql_mgr:update(2, "test_mysql", {pid = "123458", value = 40}, {pid = "123457"})
    log_info("db update code: %s, err = %s", ucode, serialize(uerr))
    local dcode, derr = mysql_mgr:delete(2, "test_mysql", {pid = "123456"}, true)
    log_info("db delete code: %s, err = %s", dcode, serialize(derr))
    dcode, derr = mysql_mgr:delete(2, "test_mysql", {pid = "123458"})
    log_info("db delete code: %s, err = %s", dcode, serialize(derr))
    ]]
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