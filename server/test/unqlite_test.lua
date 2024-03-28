-- unqlite_test.lua
local log_debug     = logger.debug
local jsoncodec     = json.jsoncodec

local driver = unqlite.create()
local jcodec = jsoncodec()

driver.set_codec(jcodec)
driver.open("./unqlite/xxx.db")

local a = driver.put("abc1", {a=123})
local b = driver.put("abc2", "234")
local c = driver.put("abc3", "235")
local d = driver.put("abc4", "236")
log_debug("put: {}-{}-{}-{}", a, b, c, d)

for i = 1, 6 do
    local da,rc = driver.get("abc" .. i)
    log_debug("get-{}: {}-{}", i, da,rc)
end

local r, k, v = driver.cursor_first()
while v do
    log_debug("cursor1: {}={}->{}", k, v, r)
    r, k, v = driver.cursor_next()
end

r, k, v = driver.cursor_seek("abc2")
while v do
    log_debug("cursor2: {}={}->{}", k, v, r)
    r, k, v = driver.cursor_next()
end

r, k, v = driver.cursor_last()
while v do
    log_debug("cursor3: {}={}->{}", k, v, r)
    r, k, v = driver.cursor_prev()
end

a = driver.put("abc4", {a=234})
b = driver.put("abc5", "235")
log_debug("put: {}-{}", a, b)
for i = 1, 6 do
    local da,rc = driver.get("abc" .. i)
    log_debug("get-{}: {}-{}", i, da,rc)
end

b = driver.del("abc4")
a = driver.del("abc5")
log_debug("del: {}-{}", a, b)
for i = 1, 6 do
    local da,rc = driver.get("abc" .. i)
    log_debug("del_get-{}: {}-{}", i, da,rc)
end

