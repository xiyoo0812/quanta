--unqlite.lua
local unqlite           = require("lunqlite")

local log_err           = logger.err
local log_dump          = logger.dump
local log_debug         = logger.debug
local sformat           = string.format

local update_mgr        = quanta.get("update_mgr")

local UNQLITE_OK        = unqlite.UNQLITE_CODE.UNQLITE_OK
local UNQLITE_NOTFOUND  = unqlite.UNQLITE_CODE.UNQLITE_NOTFOUND

local SUCCESS           = quanta.enum("KernCode", "SUCCESS")
local BENCHMARK         = environ.number("QUANTA_DB_BENCHMARK")
local AUTOINCKEY        = environ.get("QUANTA_DB_AUTOINCKEY", "QUANTA:COUNTER:AUTOINC")

local KVDB_PATH         = environ.get("QUANTA_KVDB_PATH", "./kvdb/")

local Unqlite = singleton()
local prop = property(Unqlite)
prop:reader("driver", nil)
prop:reader("lcodec", nil)
prop:reader("name", nil)

function Unqlite:__init()
    stdfs.mkdir(KVDB_PATH)
    update_mgr:attach_quit(self)
end

function Unqlite:on_quit()
    self:close()
    log_debug("[Unqlite][on_quit]")
end

function Unqlite:close()
    if self.driver then
        self.driver.close()
        self.driver = nil
    end
end

function Unqlite:open(name)
    local driver = unqlite.create()
    local lcodec = luakit.luacodec()
    driver.set_codec(lcodec)
    self.driver = driver
    self.lcodec = lcodec
    self.name = sformat("%s%s.db", KVDB_PATH, name)
    local rc = driver.open(self.name)
    log_debug("[Unqlite][open] open Unqlite {}:{}!", name, rc)
end

function Unqlite:put(key, value, sheet)
    log_dump("[Unqlite][put] {}.{}={}", sheet, key, value)
    key = sheet and sformat("%s:%s", sheet, key) or key
    local code = self.driver.put(key, value)
    if code ~= UNQLITE_OK then
        log_err("[Unqlite][put] put key {} failed: {}!", key, code)
        return false
    end
    return true
end

function Unqlite:get(key, sheet)
    key = sheet and sformat("%s:%s", sheet, key) or key
    local data, rc = self.driver.get(key)
    log_dump("[Unqlite][get] {}.{}={}={}", sheet, key, data, rc)
    if rc == UNQLITE_NOTFOUND or rc == UNQLITE_OK then
        return data, true
    end
    return nil, false
end

function Unqlite:del(key, sheet)
    key = sheet and sformat("%s:%s", sheet, key) or key
    local rc =  self.driver.del(key)
    return rc == UNQLITE_NOTFOUND or rc == UNQLITE_OK
end

function Unqlite:autoinc_id()
    local driver = self.driver
    local id, rc = driver.get(AUTOINCKEY)
    if rc ~= UNQLITE_NOTFOUND and rc ~= UNQLITE_OK then
        return false
    end
    if not id then id = BENCHMARK end
    if driver.put(AUTOINCKEY, id + 1) ~= UNQLITE_OK then
        return false
    end
    return true, SUCCESS, id
end

--迭代器
function Unqlite:iter(key)
    local flag = nil
    local driver = self.driver
    local function iter()
        local _, k, v
        if not flag then
            flag = true
            if key then
                _, k, v =driver.cursor_seek(key)
            else
                _, k, v = driver.cursor_first()
            end
        else
            _, k, v = driver.cursor_next()
        end
        return k, v
    end
    return iter
end

--迭代器
function Unqlite:riter(key)
    local flag = nil
    local driver = self.driver
    local function iter()
        local _, k, v
        if not flag then
            flag = true
            if key then
                _, k, v =driver.cursor_seek(key)
            else
                _, k, v = driver.cursor_last()
            end
        else
            _, k, v = driver.cursor_prev()
        end
        return k, v
    end
    return iter
end

quanta.unq_driver = Unqlite()

return Unqlite
