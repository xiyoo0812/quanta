-- sqlite_test.lua
local sqlite        = require("lsqlite")

local jsoncodec     = json.jsoncodec

local SQLITE_OK     = sqlite.SQLITE_CODE.SQLITE_OK

local TestCase      = import("test/case.lua")
local SqliteTest    = class(TestCase)

function SqliteTest:__init(name, addr, cleanup)
    self.temp_dir = "quanta_sqlite_test"
end

function SqliteTest:setup()
    self:prepare_temp()
    self.dbfile = self.addr or self:temp_path("test.db")
    self.driver = sqlite.create()
    self.driver.set_codec(jsoncodec())
    local rc = self.driver.open(self.dbfile)
    self:report("open db", rc == SQLITE_OK, rc, rc)
end

function SqliteTest:on_cleanup()
    pcall(function()
        if self.driver then
            pcall(function() self.driver.exec("drop table if exists PLAYER") end)
            self.driver.close()
            self.driver = nil
        end
        self:cleanup_temp()
    end)
end

function SqliteTest:run()
    local driver = self.driver
    local function row_count()
        local code, rows = driver.find("select count(*) as cnt from PLAYER")
        return code == SQLITE_OK and rows[1] and tonumber(rows[1].cnt) or -1
    end

    --1. DDL
    local rc, err = driver.exec("drop table if exists PLAYER")
    self:report("drop table", rc == SQLITE_OK, rc, err)
    rc, err = driver.exec("create table PLAYER (KEY int primary key not null, VALUE text, SCORE int)")
    self:report("create table", rc == SQLITE_OK, rc, err)

    --2. insert (exec)
    rc, err = driver.exec("insert into PLAYER (KEY, VALUE, SCORE) values (1, 'Paul1', 80)")
    self:report("insert row1", rc == SQLITE_OK, rc, err)
    rc, err = driver.exec("insert into PLAYER (KEY, VALUE, SCORE) values (2, 'Paul2', 90)")
    self:report("insert row2", rc == SQLITE_OK, rc, err)
    self:report("count after insert (expect 2)", row_count() == 2, row_count(), row_count())

    --3. find 条件/别名
    local code, rows = driver.find("select VALUE, SCORE from PLAYER where KEY = 1")
    self:report("find where (VALUE=Paul1)", code == SQLITE_OK and rows[1] and rows[1].VALUE == "Paul1", rows[1], rows)

    --4. update + 验证
    rc, err = driver.exec("update PLAYER set SCORE = 100 where KEY = 1")
    self:report("update row", rc == SQLITE_OK, rc, err)
    code, rows = driver.find("select SCORE from PLAYER where KEY = 1")
    self:report("verify update (SCORE=100)", code == SQLITE_OK and tonumber(rows[1].SCORE) == 100, rows[1], rows)

    --5. replace (主键幂等)
    rc, err = driver.exec("replace into PLAYER (KEY, VALUE, SCORE) values (2, 'Paul22', 60)")
    self:report("replace row", rc == SQLITE_OK, rc, err)
    self:report("count after replace (still 2)", row_count() == 2, row_count(), row_count())

    --6. 聚合/排序分页
    code, rows = driver.find("select sum(SCORE) as total, max(SCORE) as mx from PLAYER")
    self:report("aggregate sum/max", code == SQLITE_OK and rows[1] and tonumber(rows[1].total) == 160, rows[1], rows)
    code, rows = driver.find("select * from PLAYER order by KEY desc limit 1")
    self:report("order by + limit", code == SQLITE_OK and rows[1] and tonumber(rows[1].KEY) == 2, rows[1], rows)

    --7. delete
    rc, err = driver.exec("delete from PLAYER where KEY = 1")
    self:report("delete row", rc == SQLITE_OK, rc, err)
    self:report("count after delete (expect 1)", row_count() == 1, row_count(), row_count())

    --8. prepare + bind + exec
    local pc, st_insert = driver.prepare("insert into PLAYER (KEY, VALUE, SCORE) values (?, ?, ?)")
    self:report("prepare insert", pc == SQLITE_OK and st_insert ~= nil, pc, st_insert)
    if st_insert then
        st_insert.bind(1, 3)
        st_insert.bind(2, "Paul3")
        st_insert.bind(3, 70)
        local ic, ierr2 = st_insert.exec()
        self:report("stmt bind+exec", ic == SQLITE_OK or ic == sqlite.SQLITE_CODE.SQLITE_DONE, ic, ierr2)
        st_insert.close()
    end

    --9. stmt run (带参数快捷执行)
    local pc2, st_select = driver.prepare("select VALUE from PLAYER where KEY = ?")
    self:report("prepare select", pc2 == SQLITE_OK and st_select ~= nil, pc2, st_select)
    if st_select then
        local sc, item = st_select.run(3)
        self:report("stmt run select (VALUE=Paul3)",
            (sc == SQLITE_OK or sc == sqlite.SQLITE_CODE.SQLITE_DONE) and item[1] and item[1].VALUE == "Paul3", item[1], item)
        st_select.close()
    end

    --10. 事务回滚
    local before = row_count()
    driver.exec("begin")
    driver.exec("insert into PLAYER (KEY, VALUE, SCORE) values (99, 'tmp', 1)")
    local rc2, err2 = driver.exec("rollback")
    self:report("transaction rollback", rc2 == SQLITE_OK, rc2, err2)
    self:report("count unchanged after rollback", row_count() == before, row_count(), before)
end

return SqliteTest
