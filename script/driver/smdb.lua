-- smdb.lua
local smdb          = require("lsmdb")
--smdb.lua
local log_err       = logger.err
local log_dump      = logger.dump
local log_debug     = logger.debug
local sformat       = string.format
local scopy_file    = stdfs.copy_file

local update_mgr    = quanta.get("update_mgr")

local OVERWRITE     = stdfs.copy_options.overwrite_existing

local SUCCESS       = quanta.enum("KernCode", "SUCCESS")
local BENCHMARK     = environ.number("QUANTA_DB_BENCHMARK")
local AUTOINCKEY    = environ.get("QUANTA_DB_AUTOINCKEY", "QUANTA:COUNTER:AUTOINC")

local KVDB_PATH     = environ.get("QUANTA_KVDB_PATH", "./kvdb/")

local SMDB = singleton()
local prop = property(SMDB)
prop:reader("driver", nil)
prop:reader("jcodec", nil)

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
    self:close()
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

function SMDB:saveas(new_name)
    self:close()
    local nfname = sformat("%s%s.db", KVDB_PATH, new_name)
    local ok, err = scopy_file(self.name, nfname, OVERWRITE)
    if not ok then
        log_err("[Sqlite][saveas] copy {} to  {} fail: {}", self.name, nfname, err)
        return false
    end
    self:open(new_name)
    return true
end

function SMDB:put(key, value, sheet)
    log_dump("[SMDB][put] {}.{}={}", sheet, key, value)
    return self.driver.put(sformat("%s:%s", key, sheet), value)
end

function SMDB:get(key, sheet)
    local data = self.driver.get(sformat("%s:%s", key, sheet))
    log_dump("[SMDB][get] {}.{}={}", sheet, key, data)
    return data or {}, true
end

function SMDB:del(key, sheet)
    self.driver.del(sformat("%s:%s", key, sheet))
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

quanta.smdb_driver = SMDB()

return SMDB
