-- sqlite.lua
local sqlite        = require("lsqlite")

local log_err       = logger.err
local log_dump      = logger.dump
local log_debug     = logger.debug
local sformat       = string.format

local update_mgr    = quanta.get("update_mgr")

local SQLITE_OK     = sqlite.SQLITE_CODE.SQLITE_OK
local SQLITE_DONE   = sqlite.SQLITE_CODE.SQLITE_DONE
local SQLITE_NFOUND = sqlite.SQLITE_CODE.SQLITE_NOTFOUND

local SUCCESS       = quanta.enum("KernCode", "SUCCESS")

local BENCHMARK     = environ.number("QUANTA_DB_BENCHMARK")
local KVDB_PATH     = environ.get("QUANTA_KVDB_PATH", "./kvdb/")
local AUTOINCKEY    = environ.get("QUANTA_DB_AUTOINCKEY", "QUANTA:COUNTER:AUTOINC")

local Sqlite = singleton()
local prop = property(Sqlite)
prop:reader("name", nil)
prop:reader("driver", nil)
prop:reader("prepares", {})

function Sqlite:__init()
    stdfs.mkdir(KVDB_PATH)
    update_mgr:attach_quit(self)
end

function Sqlite:on_quit()
    self:close()
    log_debug("[Sqlite][on_quit]")
end

function Sqlite:close()
    if self.driver then
        log_debug("[Sqlite][close] close sqlite!")
        for _, stmts in pairs(self.prepares) do
            for _, stmt in pairs(stmts) do
                stmt.close()
            end
        end
        self.prepares = {}
        self.driver.close()
        self.driver = nil
    end
end

function Sqlite:open(name)
    local driver = sqlite.create()
    local jcodec = json.jsoncodec()
    driver.set_codec(jcodec)
    self.driver = driver
    self.jcodec = jcodec
    self.name = sformat("%s%s.db", KVDB_PATH, name)
    driver.open(self.name)
    self:init_db()
    log_debug("[Sqlite][open] open sqlite {}!", name)
end

function Sqlite:register_prepare(sheet)
    local _, select = self.driver.prepare(sformat("SELECT VALUE FROM '%s' WHERE KEY = ?", sheet))
    local _, update = self.driver.prepare(sformat("REPLACE INTO '%s' (KEY, VALUE) VALUES (?, ?);", sheet))
    local _, delete = self.driver.prepare(sformat("DELETE FROM '%s' where KEY=?", sheet))
    self.prepares[sheet] = {
        select = select,
        update = update,
        delete = delete
    }
end

function Sqlite:get_prepare(sheet, primary_id)
    if not self.prepares[sheet] then
        self:init_sheet(sheet, primary_id)
    end
    return self.prepares[sheet]
end

function Sqlite:init_db()
    -- 判断自增表是否存在
    local code, record = self.driver.find(sformat("SELECT name FROM sqlite_master WHERE type='table' AND name='%s';", AUTOINCKEY))
    if code ~= SQLITE_OK or (code == SQLITE_OK and not next(record)) then
        -- 创建自增表
        self.driver.exec(sformat("CREATE TABLE '%s' (KEY INTEGER PRIMARY KEY AUTOINCREMENT, VALUE INTEGER);", AUTOINCKEY))
        -- 插入初始数据
        self.driver.exec(sformat("INSERT INTO '%s' (KEY,VALUE) VALUES(%s,%s);", AUTOINCKEY, BENCHMARK, quanta.now))
    end
    self:register_prepare(AUTOINCKEY)
end

function Sqlite:init_sheet(sheet, primary_id)
    log_debug("[Sqlite][init_sheet] sheet:{} primary_id:{}", sheet, primary_id)
    local sql = "CREATE TABLE IF NOT EXISTS '%s' (KEY %s PRIMARY KEY NOT NULL, VALUE BLOB);"
    self.driver.exec(sformat(sql, sheet, type(primary_id) == "string" and "TEXT" or "INTEGER"))
    self:register_prepare(sheet)
end

function Sqlite:put(primary_id, data, sheet)
    log_dump("[Sqlite][put] primary_id:{} data:{} sheet:{}", primary_id, data, sheet)
    local rc = self:get_prepare(sheet, primary_id).update.run(primary_id, data)
    if rc ~= SQLITE_DONE then
        log_debug("[Sqlite][put] fail rc={}", rc)
        return false
    end
    return true
end

function Sqlite:get(primary_id, sheet)
    log_dump("[Sqlite][get] sheet:{} primary_id:{}", sheet, primary_id)
    local rc, data = self:get_prepare(sheet, primary_id).select.run(primary_id)
    if rc == SQLITE_NFOUND or rc == SQLITE_DONE then
        return (data[1] and data[1].VALUE) and data[1].VALUE or {}, true
    end
    return {}, false
end

function Sqlite:del(primary_id, sheet)
    local rc = self:get_prepare(sheet, primary_id).delete.run(primary_id)
    return rc == SQLITE_NFOUND or rc == SQLITE_OK
end

function Sqlite:drop(dbname)
    self.driver.exec(sformat("DROP TABLE '%s';", dbname))
end

function Sqlite:autoinc_id()
    local sql = "INSERT INTO '%s' (VALUE) VALUES(%s); SELECT last_insert_rowid() AS AUTOINC_ID;"
    local code, record = self.driver.find(sformat(sql, AUTOINCKEY, quanta.now))
    if code ~= SQLITE_OK or not next(record) then
        log_err("[Sqlite][autoinc_id] update fail code:{} record:{}", code, record)
        return false
    end
    return true, SUCCESS, record[1].AUTOINC_ID
end

quanta.sdb_driver = Sqlite()

return Sqlite
