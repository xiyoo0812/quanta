-- mongo_test.lua
require("lbson")

local bdate         = bson.date

local mongo_mgr     = quanta.load("mongo_mgr")
local thread_mgr    = quanta.get("thread_mgr")

local PRIMARY       = 1234567
local COLL          = "test_mongo"

local TestCase = import("test/case.lua")
local MongoTest = class(TestCase)

function MongoTest:setup()
    quanta.setenv("QUANTA_MONGO_URL", self.addr)
    import("db/mongo_mgr.lua")
    mongo_mgr = quanta.get("mongo_mgr")
    thread_mgr:sleep(2000)
    mongo_mgr:delete(PRIMARY, COLL, {})
end

function MongoTest:teardown()
    mongo_mgr:delete(PRIMARY, COLL, {})
end

function MongoTest:run()
    --1. count 空集合
    local code, count = mongo_mgr:count(COLL, {})
    self:report("count empty (expect 0)", code == 0 and count == 0, count, count)

    --2. insert
    local icode, ierr = mongo_mgr:insert(PRIMARY, COLL, { pid = 123456, data = { a = 1, b = 2 } })
    self:report("insert row1", icode == 0, ierr, ierr)
    icode, ierr = mongo_mgr:insert(PRIMARY, COLL, { pid = 123457, data = { a = 1, b = 4 } })
    self:report("insert row2", icode == 0, ierr, ierr)

    --3. count
    code, count = mongo_mgr:count(COLL, {})
    self:report("count after insert (expect 2)", code == 0 and count == 2, count, count)

    --4. find 全量 + find_one 条件
    local fcode, res = mongo_mgr:find(PRIMARY, COLL, {}, { _id = 0 })
    self:report("find all (expect 2 rows)", fcode == 0 and type(res) == "table" and #res == 2, res and #res, res)
    local ocode, one = mongo_mgr:find_one(PRIMARY, COLL, { pid = 123456 }, { _id = 0 })
    self:report("find_one (pid=123456)", ocode == 0 and one and one.pid == 123456, one, one)

    --5. update
    local ucode, uerr = mongo_mgr:update(PRIMARY, COLL, { ["$set"] = { pid = 123458, data = { a = 1, b = 9 } } }, { pid = 123457 })
    self:report("update row", ucode == 0, uerr, uerr)
    code, count = mongo_mgr:count(COLL, { pid = 123458 })
    self:report("verify update (pid=123458)", code == 0 and count == 1, count, count)

    --6. find_and_modify (原子取旧值并 +inc)
    local macode, mares = mongo_mgr:find_and_modify(PRIMARY, COLL, { ["$inc"] = { value = 5 } }, { pid = 123458 }, true, { value = 1 }, true)
    self:report("find_and_modify", macode == 0, mares, mares)

    --7. delete
    local ecode, eres = mongo_mgr:delete(PRIMARY, COLL, { pid = 123458 })
    self:report("delete row", ecode == 0, eres, eres)
    code, count = mongo_mgr:count(COLL, { pid = 123458 })
    self:report("verify delete (expect 0)", code == 0 and count == 0, count, count)

    --8. index: create / list / drop
    local icode2, ierr2 = mongo_mgr:create_indexes(COLL, { { key = { pid = 1 }, name = "idx_pid", unique = true } })
    self:report("create_indexes", icode2 == 0, ierr2, ierr2)
    local lcode, lres = mongo_mgr:execute(PRIMARY, "listIndexes", COLL)
    self:report("listIndexes", lcode == 0, lres, lres)
    local dcode, derr = mongo_mgr:drop_indexes(COLL, "idx_pid")
    self:report("drop_indexes", dcode == 0, derr, derr)

    --9. aggregate: 按 pid 分组计数
    local acode, ares = mongo_mgr:aggregate(COLL, {
        { ["$group"] = { _id = "$pid", total = { ["$sum"] = 1 } } },
    }, { "cursor", {} })
    self:report("aggregate group", acode == 0 and type(ares) == "table", ares, ares)

    --10. bulkwrite: 批量 insert + update + delete
    local bcode, bres = mongo_mgr:bulkwrite({
        { "insert", COLL, "document", { pid = 200001, val = 1 } },
        { "insert", COLL, "document", { pid = 200002, val = 1 } },
        { "update", COLL, "updateMods", { ["$set"] = { val = 2 } }, "filter", { pid = 200001 }, "multi", true },
        { "delete", COLL, "filter", { pid = 200002 }, "multi", true },
    }, true)
    self:report("bulkwrite", bcode == 0, bres, bres)
    code, count = mongo_mgr:count(COLL, { pid = 200001 })
    self:report("verify bulkwrite (pid=200001 val=2)", code == 0 and count == 1, count, count)

    --11. TTL 索引 + 日期写入
    mongo_mgr:create_indexes(COLL .. "_ttl", { { key = { expire = 1 }, expireAfterSeconds = 0, name = "ttl" } })
    local tcode, terr = mongo_mgr:insert(PRIMARY, COLL .. "_ttl", { pid = 1, expire = bdate(quanta.now + 3600) })
    self:report("insert with bson date", tcode == 0, terr, terr)
    mongo_mgr:delete(PRIMARY, COLL .. "_ttl", {})
end

return MongoTest
