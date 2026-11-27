-- mysql_test.lua
local mysql_mgr     = quanta.load("mysql_mgr")
local thread_mgr    = quanta.get("thread_mgr")

local TestCase      = import("test/case.lua")
local MysqlTest     = class(TestCase)

local function exec(sql)
    local code, res = mysql_mgr:query(1, sql)
    return code == 0, res
end

--结果集取标量: res 形如 {[1]={[1]={count=2}}}
local function scalar(res)
    local set = type(res) == "table" and res[1]
    local row = type(set) == "table" and set[1]
    if type(row) == "table" then
        for _, v in pairs(row) do
            return v
        end
    end
end

function MysqlTest:setup()
    quanta.setenv("QUANTA_MYSQL_URL", self.addr)
    import("db/mysql_mgr.lua")
    mysql_mgr = quanta.get("mysql_mgr")
    thread_mgr:sleep(2000)      --等驱动建库并建池就绪
end

function MysqlTest:on_cleanup()
    exec("drop table if exists test_mysql")
end

function MysqlTest:run()
    --1. DDL: drop + create
    local ok, res = exec("drop table if exists test_mysql")
    self:report("drop table if exists", ok, res, res)
    ok, res = exec("create table test_mysql (id int auto_increment, pid int, value int, name varchar(32), primary key (id))")
    self:report("create table", ok, res, res)

    --2. insert + last_insert_id
    ok, res = exec("insert into test_mysql (pid, value, name) values (123457, 40, 'alice')")
    self:report("insert row1", ok, res, res)
    ok, res = exec("insert into test_mysql (pid, value, name) values (123456, 20, 'bob')")
    self:report("insert row2", ok, res, res)

    --3. count + 标量读取
    ok, res = exec("select count(*) as count from test_mysql")
    self:report("select count (expect 2)", ok and tonumber(scalar(res)) == 2, scalar(res), res)

    --4. select 条件 + 字段
    ok, res = exec("select * from test_mysql where pid = 123457")
    local row = type(res) == "table" and res[1] and res[1][1]
    self:report("select where (name=alice)", ok and row and row.name == "alice", row, res)

    --5. update + 影响行数
    ok, res = exec("update test_mysql set value = 99 where pid = 123456")
    self:report("update row", ok, res, res)
    ok, res = exec("select value from test_mysql where pid = 123456")
    self:report("verify update (value=99)", ok and tonumber(scalar(res)) == 99, scalar(res), res)

    --6. replace into (主键幂等)
    ok, res = exec("replace into test_mysql (id, pid, value, name) values (1, 123457, 40, 'alice2')")
    self:report("replace into", ok, res, res)
    ok, res = exec("select count(*) as count from test_mysql")
    self:report("count after replace (still 2)", ok and tonumber(scalar(res)) == 2, scalar(res), res)

    --7. 聚合 + 排序分页
    ok, res = exec("select sum(value) as total, max(value) as mx from test_mysql")
    self:report("aggregate sum/max", ok and type(res) == "table", scalar(res), res)
    ok, res = exec("select * from test_mysql order by id desc limit 1")
    self:report("order by + limit", ok and type(res) == "table" and res[1] and res[1][1] ~= nil, res and res[1] and res[1][1], res)

    --8. delete
    ok, res = exec("delete from test_mysql where pid = 123457")
    self:report("delete row", ok, res, res)
    ok, res = exec("select count(*) as count from test_mysql")
    self:report("count after delete (expect 1)", ok and tonumber(scalar(res)) == 1, scalar(res), res)

    --9. 预处理语句 prepare + execute
    local code, prep_res = mysql_mgr:prepare("myinsert", "insert into test_mysql (pid, value) values (?, ?)")
    self:report("prepare insert", code == 0, prep_res, prep_res)
    code, prep_res = mysql_mgr:execute(1, "myinsert", 55555, 66666)
    self:report("execute insert", code == 0, prep_res, prep_res)
    code, prep_res = mysql_mgr:prepare("myselect", "select value from test_mysql where pid = ?")
    self:report("prepare select", code == 0, prep_res, prep_res)
    code, prep_res = mysql_mgr:execute(1, "myselect", 55555)
    self:report("execute select (value=66666)", code == 0, scalar(prep_res), prep_res)

    --10. 事务回滚: begin -> insert -> rollback -> 计数不变
    local before
    local _, count_res = exec("select count(*) as count from test_mysql")
    before = tonumber(scalar(count_res)) or 0
    exec("start transaction")
    exec("insert into test_mysql (pid, value) values (77777, 1)")
    ok, res = exec("rollback")
    self:report("transaction rollback", ok, res, res)
    ok, res = exec("select count(*) as count from test_mysql")
    self:report("count unchanged after rollback", ok and tonumber(scalar(res)) == before, scalar(res), res)
end

return MysqlTest
