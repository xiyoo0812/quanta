# lbuffer
一个提供给C/Lua使用的内存buffer操作库。

# 依赖
- [lua](https://github.com/xiyoo0812/lua.git)5.2以上
- 项目路径如下<br>
  |--proj <br>
  &emsp;|--lua <br>
  &emsp;|--lbuffer

# 编译
- msvc: 准备好lua依赖库并放到指定位置，将proj文件加到sln后编译。
- linux: 准备好lua依赖库并放到指定位置，执行make -f lbuffer.mak

# 用法
```lua
--buffer_test.lua
local lbuffer       = require("lbuffer")

local log_debug     = logger.debug
local lencode       = lbuffer.encode
local ldecode       = lbuffer.decode
local lserialize    = lbuffer.serialize
local lunserialize  = lbuffer.unserialize

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

local ss = lserialize(t)
log_debug("serialize-> aaa: %s", ss)
local tt = lunserialize(ss)
for k, v in pairs(tt) do
    log_debug("unserialize k=%s, v=%s", k, v)
end

--encode
----------------------------------------------------------------
local a = 1
local b = 2
local c = 4
local es = lencode(a, b, c, 5)
log_debug("encode-> aa: %d, %s", #es, es)
local da, db, dc, dd = ldecode(es)
log_debug("decode-> %s, %s, %s, %s", da, db, dc, dd)
```