# lcodec
一个提供给C/Lua使用的内存buffer操作以及编解码库。

# 依赖
- [lua](https://github.com/xiyoo0812/lua.git)5.2以上
- [luakit](https://github.com/xiyoo0812/luakit.git)
- 项目路径如下<br>
  |--proj <br>
  &emsp;|--lua <br>
  &emsp;|--luakit <br>
  &emsp;|--lcodec

# 编译
- msvc: 准备好lua依赖库并放到指定位置，将proj文件加到sln后编译。
- linux: 准备好lua依赖库并放到指定位置，执行make -f lcodec.mak

# 用法
```lua
--codec_test.lua
local lcrypt        = require("lcrypt")
local lcodec        = require("lcodec")

local log_debug     = logger.debug
local log_dump      = logger.dump
local lhex_encode   = lcrypt.hex_encode

local encode        = lcodec.encode
local decode        = lcodec.decode
local encode_slice  = lcodec.encode_slice
local decode_slice  = lcodec.decode_slice
local serialize     = lcodec.serialize
local unserialize   = lcodec.unserialize

--guid
----------------------------------------------------------------
local guid = lcodec.guid_new(5, 512)
local sguid = lcodec.guid_tostring(guid)
log_debug("newguid-> guid: %s, n2s: %s", guid, sguid)
local nguid = lcodec.guid_number(sguid)
local s2guid = lcodec.guid_tostring(nguid)
log_debug("convert-> guid: %s, n2s: %s", nguid, s2guid)
local nsguid = lcodec.guid_string(5, 512)
log_debug("newguid: %s", nsguid)
local group = lcodec.guid_group(nsguid)
local index = lcodec.guid_index(guid)
local time = lcodec.guid_time(guid)
log_debug("ssource-> group: %s, index: %s, time:%s", group, index, time)
local group2, index2, time2 = lcodec.guid_source(guid)
log_debug("nsource-> group: %s, index: %s, time:%s", group2, index2, time2)

--serialize
----------------------------------------------------------------
local m = {f = 3}
local t = {
    [3.63] = 1, 2, 3, 4,
    a = 2,
    b = {
        s = 3, d = "4"
    },
    e = true,
    g = m,
}
local ss = serialize(t)
log_debug("serialize-> aaa: %s", ss)

local tt = unserialize(ss)
for k, v in pairs(tt) do
    log_debug("unserialize k=%s, v=%s", k, v)
end

--encode
local e = {a = 1, c = {ab = 2}}
local bufe = encode(e)
local slice = encode_slice(e)
local bufs = slice.string()
log_debug("encode-> bufe: %d, %s", #bufe, lhex_encode(bufe))
log_debug("encode-> bufs: %d, %s", #bufs, lhex_encode(bufs))

local datas = decode_slice(slice)
log_debug("decode-> %s", datas)
local datae = decode(bufe, #bufe)
log_debug("decode-> %s", datae)

local a = 1
local b = 2
local c = 4
local es = encode_slice(a, b, c, 5)
local ess = es.string()
log_debug("encode-> aa: %d, %s", #ess, lhex_encode(ess))
local da, db, dc, dd = decode_slice(es)
log_debug("decode-> %s, %s, %s, %s", da, db, dc, dd)

--dump
log_dump("dump-> a: %s", t)

```