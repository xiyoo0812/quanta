--zip_test.lua
require("luazip")

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
local jdata = json.encode(data, false)
log_info("data: {}=>{}",  #jdata, timer.now_cs() - j1)

local t1 = timer.now_ms()
local zstdc = zip.zstd_encode(jdata, false)
for i = 1, 2000 do
    zip.zstd_encode(jdata)
end
log_info("zstd_encode: {}=>{}",  #zstdc, timer.now_ms() - t1)
local t2 = timer.now_ms()
local zstdd = zip.zstd_decode(zstdc, false)
for i = 1, 2000 do
    zip.zstd_decode(zstdc)
end
log_info("zstd_decode: {}=>{}",  #zstdd, timer.now_ms() - t2)

local l1 = timer.now_ms()
local lz4c = zip.lz4_encode(jdata, false)
for i = 1, 2000 do
    zip.lz4_encode(jdata)
end
log_info("lz4_encode: {}=>{}",  #lz4c, timer.now_ms() - l1)
local l2 = timer.now_ms()
local lz4d = zip.lz4_decode(lz4c, false)
for i = 1, 2000 do
    zip.lz4_decode(lz4c)
end
log_info("lz4_decode: {}=>{}",  #lz4d, timer.now_ms() - l2)

local z1 = timer.now_ms()
local z4c = zip.zlib_encode(jdata, false)
for i = 1, 2000 do
    zip.zlib_encode(jdata)
end
log_info("zlib_encode: {}=>{}",  #z4c, timer.now_ms() - z1)
local z2 = timer.now_ms()
local z4d = zip.zlib_decode(z4c, false)
for i = 1, 2000 do
    zip.zlib_decode(z4c)
end
log_info("zlib_decode: {}=>{}",  #z4d, timer.now_ms() - z2)

local g1 = timer.now_ms()
local gz4c = zip.gzip_encode(jdata, false)
for i = 1, 2000 do
    zip.gzip_encode(jdata)
end
log_info("gzip_encode: {}=>{}",  #gz4c, timer.now_ms() - g1)
local g2 = timer.now_ms()
local gz4d = zip.gzip_decode(gz4c, false)
for i = 1, 2000 do
    zip.gzip_decode(gz4c)
end
log_info("gzip_decode: {}=>{}",  #gz4d, timer.now_ms() - g2)

local d1 = timer.now_ms()
local def4c = zip.deflate_encode(jdata, false)
for i = 1, 2000 do
    zip.deflate_encode(jdata)
end
log_info("deflate_encode: {}=>{}", #def4c, timer.now_ms() - d1)
local d2 = timer.now_ms()
local def4d = zip.deflate_decode(def4c, false)
for i = 1, 2000 do
    zip.deflate_decode(def4c)
end
log_info("deflate_decode: {}=>{}",  #def4d, timer.now_ms() - d2)

local s1 = timer.now_ms()
local snappyc = zip.snappy_encode(jdata, false)
for i = 1, 2000 do
    zip.snappy_encode(jdata)
end
log_info("snappy_encode: {}=>{}", #snappyc, timer.now_ms() - s1)
local s2 = timer.now_ms()
local snappyd = zip.snappy_decode(snappyc, false)
for i = 1, 2000 do
    zip.snappy_decode(snappyc)
end
log_info("snappy_decode: {}=>{}",  #snappyd, timer.now_ms() - s2)
