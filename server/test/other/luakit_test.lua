--luakit_test.lua

local log_dump  = logger.dump

local value = {
    error_code = 100005,
    user_id = 23024214324234,
    roles = {
        {role_id = 134234234, name = "asdasdas3", gender= 1, model = 231323},
        {role_id = 134234233, name = "asdasdas1", gender= 2, model = 231324},
        {role_id = 134234234, name = "asdasdas2", gender= 3, model = 231325},
    }
}

local sval = string.serialize(value)
log_dump("luakit serialize:{}", sval)
local value2 = string.unserialize(sval)
log_dump("luakit unserialize:{}", value2)

local tval = string.title("hello world")
local uval = string.untitle("Hello world")
log_dump("luakit title:{}, untitle:{}", tval, uval)

local stv1 = string.starts_with("hello world", "hello")
local stv2 = string.starts_with("hello world", "world")
log_dump("luakit starts_with:{}, {}", stv1, stv2)

local etv1 = string.ends_with("hello world", "hello")
local etv2 = string.ends_with("hello world", "world")
log_dump("luakit ends_with:{}, {}", etv1, etv2)

local spval = string.split("hello world", " ")
log_dump("luakit split:{}", spval)

local vv = { a = 1, b = 2, c = 3, s = "hello world", d = { x = 1 }}
local size = table.size(vv)
log_dump("luakit size:{}", size)

local keys = table.keys(vv)
log_dump("luakit keys:{}", keys)
local vals = table.vals(vv)
log_dump("luakit vals:{}", vals)
local kvals = table.kvals(vv)
log_dump("luakit kvals:{}", kvals)

local vvc = table.copy(vv)
vvc.d.x = 2
log_dump("luakit copy: old :{}, new: {}", vv, vvc)
local vvdc = table.deepcopy(vv)
vvdc.d.x = 3
log_dump("luakit deepcopy: old :{}, new: {}", vv, vvdc)

local nvv = { 1, 2, 2, 3, 4, "hello world"}
log_dump("luakit is_array: {}, {}", table.is_array(vv), table.is_array(nvv))

local index1 = table.indexof(vv, 2)
local index2 = table.indexof(nvv, 2)
log_dump("luakit indexof: {}, {}", index1, index2)

local num = table.pushback(nvv, 5, 6, 7)
log_dump("luakit pushback: {}, {}", num, nvv)

local nnv2 = { 7, 8, 9 }
local nnv3 = table.join(nvv, nnv2)
log_dump("luakit join: {}, {}", nnv3, nvv)

local s1 = table.slice(nvv, 1, 3)
local s2 = table.slice(nvv, 4)
local s3 = table.slice(nvv, 10)
log_dump("luakit slice: {}, {}, {}", s1, s2, s3)

table.clean(nvv)
log_dump("luakit clean:{}", nvv)

local t = {1, 2, 3, 2, 4, 2, 5, 2, 6, 2, 7}
local deleted1 = table.erase(t, 2, true)
log_dump("luakit erase: {}, {}, {}", deleted1, #t, t)
local deleted2 = table.erase(t, 2)
log_dump("luakit erase once: {}, {}, {}", deleted2, #t, t)

for i = 1, 10 do
    log_dump(luakit.next_id())
end
