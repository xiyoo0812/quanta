--unqlite.lua
local log_debug         = logger.debug
local sformat           = string.format

local update_mgr        = quanta.get("update_mgr")

local UNQLITE_OK        = unqlite.UNQLITE_CODE.UNQLITE_OK
local UNQLITE_NOTFOUND  = unqlite.UNQLITE_CODE.UNQLITE_NOTFOUND

local BENCHMARK         = environ.number("QUANTA_DB_BENCHMARK")
local AUTOINCKEY        = environ.get("QUANTA_DB_AUTOINCKEY", "QUANTA:COUNTER:AUTOINC")

local UNQLITE_PATH      = environ.get("QUANTA_UNQLITE_PATH", "./unqlite/")

local Unqlite = singleton()
local prop = property(Unqlite)
prop:reader("driver", nil)
prop:reader("jcodec", nil)

function Unqlite:__init()
    stdfs.mkdir(UNQLITE_PATH)
    update_mgr:attach_quit(self)
end

function Unqlite:on_quit()
    if self.driver then
        log_debug("[Unqlite][on_quit]")
        self.driver.close()
        self.driver = nil
    end
end

function Unqlite:open(name)
    if not self.driver then
        local driver = unqlite.create()
        local jcodec = json.jsoncodec()
        driver.set_codec(jcodec)
        self.driver = driver
        self.jcodec = jcodec
        local rc = driver.open(sformat("%s%s.db", UNQLITE_PATH, name))
        log_debug("[Unqlite][open] open Unqlite {}:{}!", name, rc)
    end
end

function Unqlite:put(key, value)
    log_debug("[Unqlite][put] {}={}", key, value)
    return self.driver.put(key, value) == UNQLITE_OK
end

function Unqlite:get(key)
    local data, rc = self.driver.get(key)
    log_debug("[Unqlite][get] {}={}={}", key, data, rc)
    if rc == UNQLITE_NOTFOUND or rc == UNQLITE_OK then
        return data, true
    end
    return nil, false
end

function Unqlite:del(key)
    local rc =  self.driver.quick_del(key)
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
    return true, id
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
