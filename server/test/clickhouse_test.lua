-- clickhouse_test.lua
import("db/clickhouse_mgr.lua")

local log_debug     = logger.debug

local timer_mgr     = quanta.get("timer_mgr")
local clickhouse    = quanta.get("clickhouse")

timer_mgr:once(2000, function()
    local code, res_oe = clickhouse:query(1, "drop table if exists test_ck")
    log_debug("db drop table code: {}, err = {}", code, res_oe)
    code, res_oe = clickhouse:query(1, "create table if not exists test_ck (id int, pid int, value int, primary key (id)) ENGINE = MergeTree")
    log_debug("db create table code: {}, err = {}", code, res_oe)
    code, res_oe = clickhouse:query(1, "select count(*) as count from test_ck where pid=123456")
    log_debug("db select code: {}, count = {}", code, res_oe)
    code, res_oe = clickhouse:query(1, "insert into test_ck (id, pid, value) values (1, 123456, 40)")
    log_debug("db insert code: {}, count = {}", code, res_oe)
    code, res_oe = clickhouse:query(1, "select * from test_ck where pid = 123456")
    log_debug("db select code: {}, res_oe = {}", code, res_oe)
end)
