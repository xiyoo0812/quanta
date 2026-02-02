--zip_test.lua

local log_info      = logger.info

local data = {}
for i = 1, 200 do
    data[i] = {
        index = i,
        name = "name"..i,
        age = i,
        sex = i % 2 == 0 and "male" or "female"
    }
end

local j1 = timer.now_cs()
local jdata = json.encode(data)
log_info("data: {}=>{}",  #jdata, timer.now_cs() - j1)

local t1 = timer.now_ms()
local zstdc = zip.zstd_encode(jdata)
for i = 1, 20000 do
    zip.zstd_encode(jdata)
end
log_info("zstd_encode: {}=>{}",  #zstdc, timer.now_ms() - t1)
local t2 = timer.now_ms()
local zstdd = zip.zstd_decode(zstdc)
for i = 1, 20000 do
    zip.zstd_decode(zstdc)
end
log_info("zstd_decode: {}=>{}",  #zstdd, timer.now_ms() - t2)

local s1 = timer.now_ms()
local lz4c = zip.lz4_encode(jdata)
for i = 1, 20000 do
    zip.lz4_encode(jdata)
end
log_info("lz4_encode: {}=>{}",  #lz4c, timer.now_ms() - s1)
local s2 = timer.now_ms()
local lz4d = zip.lz4_decode(lz4c)
for i = 1, 20000 do
    zip.lz4_decode(lz4c)
end
log_info("lz4_decode: {}=>{}",  #lz4d, timer.now_ms() - s2)
