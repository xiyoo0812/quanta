--smdb.lua
local log_err           = logger.err
local log_dump          = logger.dump
local log_debug         = logger.debug
local sformat           = string.format

local update_mgr        = quanta.get("update_mgr")

local SUCCESS           = quanta.enum("KernCode", "SUCCESS")
local BENCHMARK         = environ.number("QUANTA_DB_BENCHMARK")
local AUTOINCKEY        = environ.get("QUANTA_DB_AUTOINCKEY", "QUANTA:COUNTER:AUTOINC")

local KVDB_PATH         = environ.get("QUANTA_KVDB_PATH", "./smdb/")

local SMDB = singleton()
local prop = property(SMDB)
prop:reader("driver", nil)
prop:reader("jcodec", nil)

function SMDB:__init()
    stdfs.mkdir(KVDB_PATH)
    update_mgr:attach_quit(self)
end

function SMDB:on_quit()
    if self.driver then
        log_debug("[SMDB][on_quit]")
        self.driver.close()
        self.driver = nil
    end
end

function SMDB:open(name)
    if not self.driver then
        local driver = smdb.create()
        if not driver.open(sformat("%s%s.db", KVDB_PATH, name)) then
            log_err("[SMDB][open] open SMDB {} failed!", name)
            return
        end
        local jcodec = json.jsoncodec()
        driver.set_codec(jcodec)
        self.driver = driver
        self.jcodec = jcodec
        log_debug("[SMDB][open] open SMDB {} success!", name)
    end
end

function SMDB:put(key, value)
    log_dump("[SMDB][put] {}={}", key, value)
    return self.driver.put(key, value)
end

function SMDB:get(key)
    local data = self.driver.get(key)
    log_dump("[SMDB][get] {}={}", key, data)
end

function SMDB:del(key)
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
function SMDB:iter(key)
    local flag = nil
    local driver = self.driver
    local function iter()
        local k, v
        if not flag then
            flag = true
            k, v = driver.cursor_first()
        else
            k, v = driver.cursor_next()
        end
        return k, v
    end
    return iter
end

quanta.sdb_driver = SMDB()

return SMDB
