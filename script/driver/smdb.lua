-- smdb.lua
local smdb          = require("lsmdb")
--smdb.lua
local log_err       = logger.err
local log_dump      = logger.dump
local log_debug     = logger.debug
local sformat       = string.format

local update_mgr    = quanta.get("update_mgr")

local SMDB_SUCCESS  = smdb.smdb_code.SMDB_SUCCESS

local SUCCESS       = quanta.enum("KernCode", "SUCCESS")
local BENCHMARK     = environ.number("QUANTA_DB_BENCHMARK")
local AUTOINCKEY    = environ.get("QUANTA_DB_AUTOINCKEY", "QUANTA:COUNTER:AUTOINC")

local KVDB_PATH     = environ.get("QUANTA_KVDB_PATH", "./kvdb/")

local SMDB = singleton()
local prop = property(SMDB)
prop:reader("driver", nil)
prop:reader("lcodec", nil)

function SMDB:__init()
    stdfs.mkdir(KVDB_PATH)
    update_mgr:attach_quit(self)
end

function SMDB:on_quit()
    self:close()
    log_debug("[SMDB][on_quit]")
end

function SMDB:close()
    if self.driver then
        log_debug("[SMDB][close]")
        self.driver.close()
        self.driver = nil
    end
end

function SMDB:open(name)
    local driver = smdb.create()
    local code = driver.open(sformat("%s%s.db", KVDB_PATH, name))
    if code ~= SMDB_SUCCESS then
        log_err("[SMDB][open] open SMDB {} failed: {}!", name, code)
        return
    end
    local lcodec = luakit.luacodec()
    driver.set_codec(lcodec)
    self.driver = driver
    self.lcodec = lcodec
    log_debug("[SMDB][open] open SMDB {} success!", name)
end

function SMDB:put(key, value, sheet)
    --log_dump("[SMDB][put] {}.{}={}", sheet, key, value)
    key = sheet and sformat("%s:%s", sheet, key) or key
    local code = self.driver.put(key, value)
    if code ~= SMDB_SUCCESS then
        log_err("[SMDB][put] put key {} failed: {}!", key, code)
        return false
    end
    return true
end

function SMDB:get(key, sheet)
    key = sheet and sformat("%s:%s", sheet, key) or key
    local data = self.driver.get(key)
    log_dump("[SMDB][get] {}.{}={}", sheet, key, data)
    return data or {}, true
end

function SMDB:del(key, sheet)
    key = sheet and sformat("%s:%s", sheet, key) or key
    self.driver.del(key)
end

function SMDB:autoinc_id()
    local driver = self.driver
    local id = driver.get(AUTOINCKEY)
    if not id then id = BENCHMARK end
    if not driver.put(AUTOINCKEY, id + 1) then
        return false
    end
    return true, SUCCESS, id
end

--迭代器
function SMDB:iter()
    local flag = nil
    local driver = self.driver
    local function iter()
        local k, v
        if not flag then
            flag = true
            k, v = driver.first()
        else
            k, v = driver.next()
        end
        return k, v
    end
    return iter
end

quanta.smdb_driver = SMDB()

return SMDB
