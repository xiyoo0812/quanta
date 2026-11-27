-- clickhouse_test.lua
local sformat       = string.format

local thread_mgr    = quanta.get("thread_mgr")
local clickhouse    = quanta.load("clickhouse_mgr")

local DBNAME        = "quanta_1"   --测试库

local TestCase = import("test/case.lua")
local ClickHouseTest = class(TestCase)

local function query(sql)
    local code, res = clickhouse:query(1, sql)
    return code == 0, res
end

local function scalar(res)
    local set = type(res) == "table" and res[1]
    local row = type(set) == "table" and set[1]
    if type(row) == "table" then
        for _, v in pairs(row) do
            return v
        end
    end
end

local function prepare(stmt, sql)
    local code, res = clickhouse:prepare(stmt, sql)
    return code == 0, res
end

local function execute(primary_id, stmt, ...)
    local code, res = clickhouse:execute(primary_id, stmt, ...)
    return code == 0, res
end

function ClickHouseTest:setup()
    quanta.setenv("QUANTA_CLICKHOUSE_URL", self.addr)
    import("db/clickhouse_mgr.lua")
    clickhouse = quanta.get("clickhouse")
    thread_mgr:sleep(2000)
    query(sformat("create database if not exists %s", DBNAME))
    query(sformat("use %s", DBNAME))
end

function ClickHouseTest:on_cleanup()
    query("drop table if exists test_ck")
end

function ClickHouseTest:run()
    --1. DDL: drop + create (MergeTree)
    local ok, res = query("drop table if exists test_ck")
    self:report("drop table if exists", ok, res, res)
    ok, res = query("create table test_ck (id int, pid int, value int) engine = MergeTree order by id")
    self:report("create table (MergeTree)", ok, res, res)

    --2. insert 单行 + 多行
    ok, res = query("insert into test_ck (id, pid, value) values (1, 123456, 40)")
    self:report("insert row1", ok, res, res)
    ok, res = query("insert into test_ck (id, pid, value) values (2, 123456, 20), (3, 123457, 60)")
    self:report("insert multiple rows", ok, res, res)

    --3. count
    ok, res = query("select count(*) as count from test_ck")
    self:report("select count (expect 3)", ok and tonumber(scalar(res)) == 3, scalar(res), res)

    --4. where
    ok, res = query("select value from test_ck where id = 1")
    self:report("select where (value=40)", ok and tonumber(scalar(res)) == 40, scalar(res), res)

    --5. 聚合
    ok, res = query("select sum(value) as total, max(value) as mx from test_ck")
    self:report("aggregate sum/max (total=120)", ok and type(res) == "table", scalar(res), res)

    --6. group by
    ok, res = query("select pid, count(*) as cnt from test_ck group by pid order by pid")
    self:report("group by", ok and type(res) == "table" and res[1] and #res[1] == 2, res and res[1], res)

    --7. order by + limit
    ok, res = query("select * from test_ck order by value desc limit 1")
    self:report("order by + limit", ok and type(res) == "table" and res[1] and res[1][1] ~= nil, res and res[1] and res[1][1], res)

    --8. prepare + execute (参数化插入, 二进制协议)
    local pok, pres = prepare("ck_insert", "insert into test_ck (id, pid, value) values (?, ?, ?)")
    self:report("prepare stmt", pok, pres, pres)
    local eok, eres = execute(1, "ck_insert", 4, 123458, 80)
    self:report("execute insert", eok, eres, eres)
    ok, res = query("select value from test_ck where id = 4")
    self:report("execute inserted value (expect 80)", ok and tonumber(scalar(res)) == 80, scalar(res), res)

    --9. prepare + execute 参数化查询
    pok, pres = prepare("ck_select", "select value from test_ck where id = ?")
    self:report("prepare select stmt", pok, pres, pres)
    eok, res = execute(1, "ck_select", 1)
    self:report("execute select (expect 40)", eok and tonumber(scalar(res)) == 40, scalar(res), res)
end

return ClickHouseTest
