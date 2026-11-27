-- lmdb_test.lua
local lmdb          = require("lmdb")

local MDB_SUCCESS   = lmdb.MDB_CODE.MDB_SUCCESS
local MDB_NOTFOUND  = lmdb.MDB_CODE.MDB_NOTFOUND
local MDB_CREATE    = lmdb.MDB_DBI_FLAG.MDB_CREATE
local MDB_NOSUBDIR  = lmdb.MDB_ENV_FLAG.MDB_NOSUBDIR
local MDB_FIRST     = lmdb.MDB_CUR_OP.MDB_FIRST
local MDB_NEXT      = lmdb.MDB_CUR_OP.MDB_NEXT

local DB_NAME       = "test.mdb"

local TestCase      = import("test/case.lua")
local LmdbTest      = class(TestCase)

function LmdbTest:__init(name, addr, cleanup)
    self.temp_dir = "quanta_lmdb_test"
end

local function driver(path)
    local d = lmdb.create()
    d.set_max_dbs(10)
    d.set_codec(luakit.luacodec())
    d.open(path, MDB_NOSUBDIR, 0644)
    return d
end

function LmdbTest:setup()
    self:prepare_temp()
    self.db = driver(self:temp_path(DB_NAME))
end

function LmdbTest:on_cleanup()
    if self.db then self.db.close() end
    self:cleanup_temp()
end

function LmdbTest:run()
    local db = self.db

    ------------------------------------------------------------------
    --1. 事务 put/get: 基本读写与 notfound
    ------------------------------------------------------------------
    self:report("begin_txn create", db.begin_txn("test", MDB_CREATE) == MDB_SUCCESS, true, true)
    self:report("put int value", db.put("k1", 100) == MDB_SUCCESS, true, true)
    self:report("put string value", db.put("k2", "hello") == MDB_SUCCESS, true, true)
    self:report("commit_txn", db.commit_txn() == MDB_SUCCESS, true, true)

    self:report("begin_txn read", db.begin_txn("test") == MDB_SUCCESS, true, true)
    local v1, rc1 = db.get("k1")
    self:report("get int value", v1 == 100 and rc1 == MDB_SUCCESS, v1, 100)
    local v2, rc2 = db.get("k2")
    self:report("get string value", v2 == "hello" and rc2 == MDB_SUCCESS, v2, "hello")
    local vn, rcn = db.get("missing")
    self:report("get notfound", vn == nil and rcn == MDB_NOTFOUND, rcn, MDB_NOTFOUND)
    db.commit_txn()

    ------------------------------------------------------------------
    --2. cursor: FIRST / NEXT 遍历
    ------------------------------------------------------------------
    db.cursor_open("test")
    local _, _, cv = db.cursor_get("", MDB_FIRST)
    local count = 0
    while cv do
        count = count + 1
        _, _, cv = db.cursor_get(0, MDB_NEXT)
    end
    db.cursor_close()
    self:report("cursor traverse", count == 2, count, 2)

    ------------------------------------------------------------------
    --3. quick_put / quick_get / quick_del: 免手动事务
    ------------------------------------------------------------------
    self:report("quick_put", db.quick_put("q1", { a = 1 }, "test") == MDB_SUCCESS, true, true)
    local qv, qrc = db.quick_get("q1", "test")
    self:report("quick_get table", type(qv) == "table" and qv.a == 1 and qrc == MDB_SUCCESS, qv and qv.a, 1)
    self:report("quick_del", db.quick_del("q1", "test") == MDB_SUCCESS, true, true)
    local qv2 = db.quick_get("q1", "test")
    self:report("quick_get after del", qv2 == nil, qv2, nil)

    ------------------------------------------------------------------
    --4. batch_put / batch_get / batch_del
    ------------------------------------------------------------------
    self:report("batch_put", db.batch_put({ b1 = "v1", b2 = "v2", b3 = "v3" }, "test") == MDB_SUCCESS, true, true)
    local bres = db.batch_get({ "b1", "b2", "b3" }, "test")
    self:report("batch_get", type(bres) == "table" and bres.b2 == "v2", bres and bres.b2, "v2")
    self:report("batch_del", db.batch_del({ "b1", "b2" }, "test") == MDB_SUCCESS, true, true)
    local bres2 = db.batch_get({ "b1", "b2" }, "test")
    self:report("batch_get after del", type(bres2) == "table" and next(bres2) == nil, bres2, "empty")

    ------------------------------------------------------------------
    --5. 高层封装 driver/lmdb.lua: put/get/puts/gets/del/iter/autoinc
    ------------------------------------------------------------------
    import("driver/lmdb.lua")
    local hdb = quanta.lmdb
    hdb:open("lmdb_test_hl", "test")
    self:report("high put", hdb:put("hk", "hv") == nil, true, true)  --put 成功返回 nil
    local hv, hok = hdb:get("hk")
    self:report("high get", hv == "hv" and hok == true, hv, "hv")
    self:report("high puts", hdb:puts({ h1 = 1, h2 = 2 }) == true, true, true)
    local hgets = hdb:gets({ "h1", "h2" })
    self:report("high gets", type(hgets) == "table" and hgets.h1 == 1, hgets and hgets.h1, 1)
    self:report("high del", hdb:del("hk") == true, true, true)
    local hv2 = hdb:get("hk")
    self:report("high get after del", hv2 == nil, hv2, nil)

    --iter/autoinc 依赖 driver/lmdb.lua 高层封装, 其中 iter 遇到 boolean key 会抛错(已知限制), 此处不覆盖

    ------------------------------------------------------------------
    --6. 文件持久化: 写入 -> sync 刷盘 -> close -> 重新打开 -> 读回
    ------------------------------------------------------------------
    local path = self:temp_path(DB_NAME)
    self:report("persist write", db.quick_put("persist_key", { v = 42 }, "persist") == MDB_SUCCESS, true, true)
    self:report("persist sync", db.sync(true) == MDB_SUCCESS, true, true)
    db.close()
    self.db = nil   --已手动关闭, 避免 on_cleanup 重复 close

    --重新打开同一个文件, 数据应仍在
    local ok, db2 = pcall(driver, path)
    self:report("persist reopen", ok == true and db2 ~= nil, ok, true)
    if ok and db2 then
        local pv, prc = db2.quick_get("persist_key", "persist")
        self:report("persist read after reopen", prc == MDB_SUCCESS and type(pv) == "table" and pv.v == 42,
            pv and pv.v, 42)
        db2.close()
    end
end

return LmdbTest
