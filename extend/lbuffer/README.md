# lbuffer
一个提供给C/Lua使用的内存buffer操作库。

# 依赖
- [lua](https://github.com/xiyoo0812/lua.git)5.2以上
- [luakit](https://github.com/xiyoo0812/luakit.git)
- 项目路径如下<br>
  |--proj <br>
  &emsp;|--lua <br>
  &emsp;|--luakit <br>
  &emsp;|--lbuffer

# 编译
- msvc: 准备好lua依赖库并放到指定位置，将proj文件加到sln后编译。
- linux: 准备好lua依赖库并放到指定位置，执行make -f lbuffer.mak

# 注意事项
- mimalloc: 参考[quanta](https://github.com/xiyoo0812/quanta.git)使用，不用则在工程文件中注释

# 用法
```lua
--buffer_test.lua
local lbuffer       = require("lbuffer")

local log_debug     = logger.debug
local serializer    = lbuffer.new_serializer()

local encode        = serializer.encode
local decode        = serializer.decode
local serialize     = serializer.serialize
local unserialize   = serializer.unserialize

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
----------------------------------------------------------------
local a = 1
local b = 2
local c = 4
local es = encode(a, b, c, 5)
log_debug("encode-> aa: %d, %s", #es, es)
local da, db, dc, dd = decode(es)
log_debug("decode-> %s, %s, %s, %s", da, db, dc, dd)
```