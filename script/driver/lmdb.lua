--lmdb.lua
local lmdb          = require("lmdb")

local log_err       = logger.err
local log_dump      = logger.dump
local log_debug     = logger.debug
local sformat       = string.format

local update_mgr    = quanta.get("update_mgr")

local MDB_SUCCESS   = lmdb.MDB_CODE.MDB_SUCCESS
local MDB_NOTFOUND  = lmdb.MDB_CODE.MDB_NOTFOUND

local MDB_NOSUBDIR  = lmdb.MDB_ENV_FLAG.MDB_NOSUBDIR

local MDB_FIRST     = lmdb.MDB_CUR_OP.MDB_FIRST
local MDB_NEXT      = lmdb.MDB_CUR_OP.MDB_NEXT
local MDB_SET       = lmdb.MDB_CUR_OP.MDB_SET

local SUCCESS       = quanta.enum("KernCode", "SUCCESS")
local BENCHMARK     = environ.number("QUANTA_DB_BENCHMARK")
local AUTOINCKEY    = environ.get("QUANTA_DB_AUTOINCKEY", "QUANTA:COUNTER:AUTOINC")

local KVDB_PATH     = environ.get("QUANTA_KVDB_PATH", "./kvdb/")

local Lmdb = singleton()
local prop = property(Lmdb)
prop:reader("driver", nil)
prop:reader("lcodec", nil)
prop:reader("sheet", nil)
prop:reader("name", nil)

function Lmdb:__init()
    stdfs.mkdir(KVDB_PATH)
    update_mgr:attach_quit(self)
end

function Lmdb:on_quit()
    self:close()
    log_debug("[Lmdb][on_quit]")
end

function Lmdb:close()
    if self.driver then
        self.driver.close()
        self.driver = nil
    end
end

function Lmdb:open(name, sheet)
    local driver = lmdb.create()
    local lcodec = luakit.luacodec()
    driver.set_max_dbs(128)
    driver.set_codec(lcodec)
    self.driver = driver
    self.lcodec = lcodec
    self.sheet = sheet
    self.name = sformat("%s%s.mdb", KVDB_PATH, name)
    local rc = driver.open(self.name, MDB_NOSUBDIR, 0644)
    log_debug("[Lmdb][open] open lmdb {}:{}!", name, rc)
end

function Lmdb:puts(objects, sheet)
    return self.driver.batch_put(objects, sheet or self.sheet) == MDB_SUCCESS
end

function Lmdb:put(key, value, sheet)
    log_dump("[Lmdb][put] {}.{}={}", key, sheet, value)
    local code = self.driver.quick_put(key, value, sheet or self.sheet)
    if code ~= MDB_SUCCESS then
        log_err("[Lmdb][put] put key {} failed: {}!", key, code)
        return false
    end
end

function Lmdb:get(key, sheet)
    local data, rc = self.driver.quick_get(key, sheet or self.sheet)
    log_dump("[Lmdb][get] {}.{}={}={}", key, sheet, data, rc)
    if rc == MDB_NOTFOUND or rc == MDB_SUCCESS then
        return data, true
    end
    return nil, false
end

function Lmdb:gets(keys, sheet)
    local res, rc = self.driver.batch_get(keys, sheet or self.sheet)
    if rc == MDB_NOTFOUND or rc == MDB_SUCCESS then
        return res, true
    end
    return nil, false
end

function Lmdb:del(key, sheet)
    local rc =  self.driver.quick_del(key, sheet or self.sheet)
    return rc == MDB_NOTFOUND or rc == MDB_SUCCESS
end

function Lmdb:dels(keys, sheet)
    local rc = self.driver.batch_del(keys, sheet or self.sheet)
    return rc == MDB_NOTFOUND or rc == MDB_SUCCESS
end

function Lmdb:drop(sheet)
    return self.driver.quick_drop(sheet or self.sheet)
end

function Lmdb:autoinc_id()
    local driver = self.driver
    driver.begin_txn()
    local id, rc = driver.get(AUTOINCKEY)
    if rc ~= MDB_NOTFOUND and rc ~= MDB_SUCCESS then
        return false
    end
    if not id then id = BENCHMARK end
    if driver.put(AUTOINCKEY, id + 1) ~= MDB_SUCCESS then
        return false
    end
    driver.commit_txn()
    return true, SUCCESS, id
end

--迭代器
function Lmdb:iter(sheet, key)
    local flag = nil
    local driver = self.driver
    driver.cursor_open(sheet or self.sheet)
    local function iter()
        local _, k, v
        if not flag then
            flag = MDB_NEXT
            _, k, v = driver.cursor_get(key, key and MDB_SET or MDB_FIRST )
        else
            _, k, v = driver.cursor_get(key, flag)
        end
        if not v then
            driver.cursor_close()
        end
        return k, v
    end
    return iter
end

quanta.mdb_driver = Lmdb()

return Lmdb
