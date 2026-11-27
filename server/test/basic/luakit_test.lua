-- luakit_test.lua
local sformat       = string.format

local TestCase      = import("test/case.lua")
local LuakitTest    = class(TestCase)

function LuakitTest:run()
    ------------------------------------------------------------------
    --1. string.serialize / unserialize 往返
    ------------------------------------------------------------------
    local src = { n = 100005, s = "hello", nested = { a = 1, b = { c = 2 } }, flag = true }
    local ss = string.serialize(src)
    self:report("serialize returns string", type(ss) == "string", type(ss), "string")
    local back = string.unserialize(ss)
    self:report("unserialize number", back and back.n == 100005, back and back.n, 100005)
    self:report("unserialize string", back and back.s == "hello", back and back.s, "hello")
    self:report("unserialize nested", back and back.nested and back.nested.b and back.nested.b.c == 2,
        back and back.nested and back.nested.b and back.nested.b.c, 2)

    ------------------------------------------------------------------
    --2. title / untitle / starts_with / ends_with / split
    ------------------------------------------------------------------
    self:report("title", string.title("hello") == "Hello", string.title("hello"), "Hello")
    self:report("untitle", string.untitle("Hello") == "hello", string.untitle("Hello"), "hello")
    self:report("starts_with true", string.starts_with("hello world", "hello") == true, true, "true")
    self:report("starts_with false", string.starts_with("hello world", "world") == false, false, "false")
    self:report("ends_with true", string.ends_with("hello world", "world") == true, true, "true")
    self:report("ends_with false", string.ends_with("hello world", "hello") == false, false, "false")
    local sp = string.split("a,b,c", ",")
    self:report("split 3 parts", type(sp) == "table" and sp[1] == "a" and sp[2] == "b" and sp[3] == "c", sp, "a/b/c")

    ------------------------------------------------------------------
    --3. table.size / keys / vals / kvals
    ------------------------------------------------------------------
    local vv = { a = 1, b = 2, c = 3 }
    self:report("table.size 3", table.size(vv) == 3, table.size(vv), 3)
    self:report("table.keys 3", #table.keys(vv) == 3, #table.keys(vv), 3)
    self:report("table.vals 3", #table.vals(vv) == 3, #table.vals(vv), 3)
    self:report("table.kvals 6", #table.kvals(vv) == 6, #table.kvals(vv), 6)

    ------------------------------------------------------------------
    --4. table.copy / deepcopy(验证浅拷贝共享、深拷贝隔离)
    ------------------------------------------------------------------
    local orig = { x = 1, d = { v = 1 } }
    local shallow = table.copy(orig)
    local deep = table.deepcopy(orig)
    shallow.x = 9
    self:report("copy top-level isolated", orig.x == 1 and shallow.x == 9, orig.x, 1)
    shallow.d.v = 100
    self:report("copy nested shared", orig.d.v == 100, orig.d.v, 100)
    orig.d.v = 7
    deep.d.v = 8
    self:report("deepcopy nested isolated", orig.d.v == 7 and deep.d.v == 8, orig.d.v, 7)

    ------------------------------------------------------------------
    --5. table.is_array / indexof / pushback / join / slice
    ------------------------------------------------------------------
    self:report("is_array true", table.is_array({ 1, 2, 3 }) == true, true, "true")
    self:report("is_array false", table.is_array({ a = 1 }) == false, false, "false")
    local arr = { 10, 20, 30 }
    self:report("indexof 20=2", table.indexof(arr, 20) == 2, table.indexof(arr, 20), 2)
    self:report("indexof missing", table.indexof(arr, 99) == nil, table.indexof(arr, 99), "nil")
    local n = table.pushback(arr, 40, 50)
    self:report("pushback count 2", n == 2, n, 2)
    self:report("pushback values", arr[4] == 40 and arr[5] == 50, sformat("%s,%s", arr[4], arr[5]), "40,50")
    --table.join(src, dst): 把 src 元素追加到 dst(改的是第2个表)
    table.join({ 60, 70 }, arr)
    self:report("join values", arr[6] == 60 and arr[7] == 70, sformat("%s,%s", arr[6], arr[7]), "60,70")
    local s1 = table.slice(arr, 1, 3)
    self:report("slice 1-3", #s1 == 3 and s1[1] == 10 and s1[3] == 30, s1, "10/20/30")
    local s2 = table.slice(arr, 4)
    self:report("slice from 4", s2[1] == 40, s2[1], 40)

    ------------------------------------------------------------------
    --6. table.clean / table.erase
    ------------------------------------------------------------------
    local t = { a = 1, b = 2 }
    table.clean(t)
    self:report("clean empties", next(t) == nil, next(t), "nil")
    --table.erase(t, value, once): once=true 只删第一个, 不传/false 删全部
    local e = { 1, 2, 2, 3, 2 }
    local deleted = table.erase(e, 2)
    self:report("erase all 2", deleted == 3 and #e == 2 and e[1] == 1 and e[2] == 3,
        sformat("deleted=%s,len=%s", deleted, #e), "3/2")
    local e2 = { 1, 2, 2, 3 }
    local d2 = table.erase(e2, 2, true)
    self:report("erase once", d2 == 1 and #e2 == 3, sformat("deleted=%s,len=%s", d2, #e2), "1/3")

    ------------------------------------------------------------------
    --7. luakit.next_id / next_id16 / next_id64 单调递增
    ------------------------------------------------------------------
    local id1, id2 = luakit.next_id(), luakit.next_id()
    self:report("next_id increasing", type(id1) == "number" and id2 > id1, sformat("%s/%s", id1, id2), "increasing")
    local i64_1, i64_2 = luakit.next_id64(), luakit.next_id64()
    self:report("next_id64 increasing", i64_2 > i64_1, sformat("%s/%s", i64_1, i64_2), "increasing")
    self:report("next_id16 number", type(luakit.next_id16()) == "number", type(luakit.next_id16()), "number")

    ------------------------------------------------------------------
    --8. luakit.encode / decode 二进制往返
    --   注意: 模块级 luakit.encode 只打包第 1 个参数(内部写死 num=1),
    --   luakit.decode 只读第 1 个参数(缓冲区串); 故每个值单独往返.
    ------------------------------------------------------------------
    local bnum = luakit.encode(123)
    self:report("encode returns string", type(bnum) == "string" and #bnum > 0, type(bnum) .. "/" .. #bnum, "string>0")
    self:report("decode number", luakit.decode(bnum) == 123, luakit.decode(bnum), 123)
    local bstr = luakit.encode("hi")
    self:report("decode string", luakit.decode(bstr) == "hi", luakit.decode(bstr), "hi")
    local btab = luakit.encode({ 1, 2, 3 })
    local back_tab = luakit.decode(btab)
    self:report("decode table", type(back_tab) == "table" and back_tab[2] == 2, back_tab, "{1,2,3}")
end

return LuakitTest
