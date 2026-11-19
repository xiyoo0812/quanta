-- pgsql_test.lua
-- 测试前置: 本地 PostgreSQL, 通过 QUANTA_PGSQL_URL 连接; addr 由注册表传入仅作目标标识
-- 覆盖: DDL/CRUD/upsert(on conflict)/聚合/排序分页/别名/预处理/事务回滚
local TestCase   = import("test/case.lua")
import("db/pgsql_mgr.lua")

local thread_mgr = quanta.get("thread_mgr")
local pgsql_mgr  = quanta.get("pgsql_mgr")

local PgsqlTest = class(TestCase)

local function exec(sql)
    local code, res = pgsql_mgr:query(1, sql)
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

function PgsqlTest:setup()
    thread_mgr:sleep(2000)
end

function PgsqlTest:teardown()
    exec("drop table if exists test_pgsql")
end

function PgsqlTest:run()
    --1. DDL
    local ok, res = exec("drop table if exists test_pgsql")
    self:report("drop table if exists", ok, res, res)
    ok, res = exec("create table test_pgsql (id serial primary key, pid int, value int, name varchar(32))")
    self:report("create table", ok, res, res)

    --2. insert
    ok, res = exec("insert into test_pgsql (pid, value, name) values (123457, 40, 'alice')")
    self:report("insert row1", ok, res, res)
    ok, res = exec("insert into test_pgsql (pid, value, name) values (123456, 20, 'bob')")
    self:report("insert row2", ok, res, res)

    --3. count
    ok, res = exec("select count(*) as count from test_pgsql")
    self:report("select count (expect 2)", ok and tonumber(scalar(res)) == 2, scalar(res), res)

    --4. select 条件
    ok, res = exec("select * from test_pgsql where pid = 123457")
    local row = type(res) == "table" and res[1] and res[1][1]
    self:report("select where (name=alice)", ok and row and row.name == "alice", row, res)

    --5. update
    ok, res = exec("update test_pgsql set value = 99 where pid = 123456")
    self:report("update row", ok, res, res)
    ok, res = exec("select value from test_pgsql where pid = 123456")
    self:report("verify update (value=99)", ok and tonumber(scalar(res)) == 99, scalar(res), res)

    --6. upsert: on conflict do update
    ok, res = exec("insert into test_pgsql (id, pid, value, name) values (1, 123457, 40, 'alice2') " ..
        "on conflict (id) do update set pid = excluded.pid, value = excluded.value, name = excluded.name")
    self:report("upsert on conflict", ok, res, res)
    ok, res = exec("select name from test_pgsql where id = 1")
    self:report("verify upsert (name=alice2)", ok and scalar(res) == "alice2", scalar(res), res)

    --7. 聚合 + 排序分页
    ok, res = exec("select sum(value) as total, max(value) as mx from test_pgsql")
    self:report("aggregate sum/max", ok and type(res) == "table", scalar(res), res)
    ok, res = exec("select * from test_pgsql order by id desc limit 1")
    self:report("order by + limit", ok and type(res) == "table" and res[1] and res[1][1] ~= nil, res and res[1] and res[1][1], res)

    --8. delete
    ok, res = exec("delete from test_pgsql where pid = 123457")
    self:report("delete row", ok, res, res)
    ok, res = exec("select count(*) as count from test_pgsql")
    self:report("count after delete (expect 1)", ok and tonumber(scalar(res)) == 1, scalar(res), res)

    --9. 预处理语句
    ok, res = pgsql_mgr:prepare("myinsert", "insert into test_pgsql (pid, value) values ($1, $2)")
    self:report("prepare insert", ok, res, res)
    ok, res = pgsql_mgr:execute(1, "myinsert", 55555, 66666)
    self:report("execute insert", ok, res, res)
    ok, res = pgsql_mgr:prepare("myselect", "select value from test_pgsql where pid = $1")
    self:report("prepare select", ok, res, res)
    ok, res = pgsql_mgr:execute(1, "myselect", 55555)
    self:report("execute select (value=66666)", ok and tonumber(scalar(res)) == 66666, scalar(res), res)

    --10. 事务回滚
    local before = 0
    ok, res = exec("select count(*) as count from test_pgsql")
    before = tonumber(scalar(res)) or 0
    exec("begin")
    exec("insert into test_pgsql (pid, value) values (77777, 1)")
    ok, res = exec("rollback")
    self:report("transaction rollback", ok, res, res)
    ok, res = exec("select count(*) as count from test_pgsql")
    self:report("count unchanged after rollback", ok and tonumber(scalar(res)) == before, scalar(res), res)
end

return PgsqlTest
