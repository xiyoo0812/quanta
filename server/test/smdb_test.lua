-- smdb_test.lua
local smdb          = require("lsmdb")

local log_debug     = logger.debug
--local jsoncodec     = json.jsoncodec
local luacodec      = luakit.luacodec

local driver = smdb.create()
local lcodec = luacodec()

driver.set_codec(lcodec)
local ok = driver.open("./smdb/xxx.db")
log_debug("open: {}", ok)

local a = driver.put("abc1", {a=123})
local b = driver.put("abc2", "234")
local c = driver.put("abc3", "335")
local d = driver.put("abc4", "436")
local e = driver.put("abc5", "536")

log_debug("put: {}-{}-{}-{}-{}", a, b, c, d, e)

for i = 1, 6 do
    local key = "abc" .. i
    local da = driver.get(key)
    log_debug("get-{}: {}", key, da)
end

local k, v = driver.first()
while v do
    log_debug("cursor: {}={}", k, v)
    k, v = driver.next()
end

b = driver.del("abc2")
a = driver.del("abc5")
c = driver.put("abc3", "4335")
log_debug("del: {}-{}-{}", a, b, c)


for i = 1, 6 do
    local key = "abc" .. i
    local da = driver.get(key)
    log_debug("del_get-{}: {}", key, da)
end

log_debug("status: {}, {}, {}", driver.count(), driver.size(), driver.capacity())

local t1 = timer.clock_ms()
local cc, dd = 100, 10000
for i = 1, dd do
    for j = 1, cc do
        local key = "abc" .. j
        local val = { a = i, b=j, t = timer.clock_ms() , key = key}
        local code = driver.put(key, val)
        if code ~= 0 then
            log_debug("put error: {}, {}", key, code)
        end
    end
end
local t2 = timer.clock_ms()
log_debug("profile： {}, {}", t2-t1, cc * dd * 1000 / (t2-t1))
log_debug("status: {}, {}, {}", driver.count(), driver.size(), driver.capacity())
