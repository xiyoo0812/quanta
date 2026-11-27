-- pgsql_test.lua
local pgsql_mgr     = quanta.load("pgsql_mgr")
local thread_mgr    = quanta.get("thread_mgr")

local TestCase      = import("test/case.lua")
local PgsqlTest     = class(TestCase)

local function exec(sql)
    local code, res = pgsql_mgr:query(1, sql)
    return code == 0, res
end

--安全转数字: 取不到返回 -1(不等于任何期望值, 让断言 FAIL 而非崩溃)
local function num(v)
    return tonumber(v) or -1
end

--取结果集首行首列. 兼容: 纯值 / 行表{列名=值} / {[1]=行表} 三种结构
local function first_value(t)
    if type(t) ~= "table" then return t end
    for _, v in pairs(t) do
        return v
    end
end

local function scalar(res)
    if type(res) ~= "table" then return res end
    local set = res[1]
    if type(set) ~= "table" then return set end
    --set 可能本身就是行表{列名=值}, 也可能 result set{[1]=行表}
    if set[1] == nil then
        return first_value(set)
    end
    return first_value(set[1])
end

function PgsqlTest:setup()
    quanta.setenv("QUANTA_PGSQL_URL", self.addr)
    import("db/pgsql_mgr.lua")
    pgsql_mgr = quanta.get("pgsql_mgr")
    thread_mgr:sleep(2000)      --等驱动建库并建池就绪
end

function PgsqlTest:on_cleanup()
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
    self:report("select count (expect 2)", ok and num(scalar(res)) == 2, scalar(res), res)

    --4. select 条件
    ok, res = exec("select * from test_pgsql where pid = 123457")
    local row = type(res) == "table" and res[1] and res[1][1]
    self:report("select where (name=alice)", ok and row and row.name == "alice", row, res)

    --5. update
    ok, res = exec("update test_pgsql set value = 99 where pid = 123456")
    self:report("update row", ok, res, res)
    ok, res = exec("select value from test_pgsql where pid = 123456")
    self:report("verify update (value=99)", ok and num(scalar(res)) == 99, scalar(res), res)

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
    self:report("count after delete (expect 1)", ok and num(scalar(res)) == 1, scalar(res), res)

    --9. 预处理语句
    local code, prep_res = pgsql_mgr:prepare("myinsert", "insert into test_pgsql (pid, value) values ($1, $2)")
    self:report("prepare insert", code == 0, prep_res, prep_res)
    code, prep_res = pgsql_mgr:execute(1, "myinsert", 55555, 66666)
    self:report("execute insert", code == 0, prep_res, prep_res)
    code, prep_res = pgsql_mgr:prepare("myselect", "select value from test_pgsql where pid = $1")
    self:report("prepare select", code == 0, prep_res, prep_res)
    code, prep_res = pgsql_mgr:execute(1, "myselect", 55555)
    self:report("execute select (value=66666)", code == 0, scalar(prep_res), prep_res)

    --10. 事务回滚
    local before
    local _, count_res = exec("select count(*) as count from test_pgsql")
    before = num(scalar(count_res))
    exec("begin")
    exec("insert into test_pgsql (pid, value) values (77777, 1)")
    ok, res = exec("rollback")
    self:report("transaction rollback", ok, res, res)
    ok, res = exec("select count(*) as count from test_pgsql")
    self:report("count unchanged after rollback", ok and num(scalar(res)) == before, scalar(res), res)
end

return PgsqlTest
