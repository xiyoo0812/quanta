-- protobuf_test.lua

local sformat       = string.format
local log_info      = logger.info

local TestCase      = import("test/case.lua")
local ProtoTest     = class(TestCase)

local NUM_MSG       = "ncmd_cs.num_message"
local TEST_MSG      = "ncmd_cs.test_message"
local ENUM_NAME     = "ncmd_cs.BtNodeId"

-- luapb 用 Lua number 承载数值; 超过 2^53 会丢精度, 故极值取 2^53-1 以内
local intmin = {
    i32 = -2147483648, s32 = -2147483648, sf32 = -2147483648,
    i64 = -9007199254740991, s64 = -9007199254740991, sf64 = -9007199254740991,
    u32 = 0, u64 = 0, f32 = 0, f64 = 0, d32 = 0, d64 = 0,
}
local intnor = {
    i32 = -60, s32 = -666, u32 = 98656, f32 = 9865688, sf32 = -6665,
    i64 = -554545, sf64 = 6568454, u64 = 98456445645, s64 = 645645,
    f64 = 88654465465, d32 = 3.141592, d64 = 3.1415926535,
}
local intmax = {
    i32 = 2147483647, s32 = 2147483647, sf32 = 2147483647,
    u32 = 4294967295, f32 = 4294967295,
    i64 = 9007199254740991, s64 = 9007199254740991, sf64 = 9007199254740991,
    u64 = 9007199254740991, f64 = 9007199254740991,
    d32 = 3.402823466e38, d64 = 1.7976931348623157e308,
}

local function roundtrip(msg, data)
    local bytes = protobuf.encode(msg, data)
    if not bytes then return nil end
    return protobuf.decode(msg, bytes)
end

local function check_fields(self, title, src, dst)
    for k, v in pairs(src) do
        local actual = dst and dst[k]
        --float32(d32) 有精度损失, 用相对误差比较; 其余类型精确比较
        local ok = k == "d32" and actual ~= nil and math.abs(actual - v) <= math.abs(v) * 1e-6
            or actual == v
        self:report(sformat("%s.%s", title, k), ok, actual, v)
    end
end

function ProtoTest:run()
    ------------------------------------------------------------------
    --1. 枚举: 名称 <-> id 双向映射
    ------------------------------------------------------------------
    local login_id = protobuf.enum(ENUM_NAME, "BT_LOGIN")
    self:report("enum name->id", login_id == 1001, login_id, 1001)
    local login_name = protobuf.enum(ENUM_NAME, 1001)
    self:report("enum id->name", login_name == "BT_LOGIN", login_name, "BT_LOGIN")

    ------------------------------------------------------------------
    --2. num_message: 最小值往返
    ------------------------------------------------------------------
    self:report("min encode non-empty", #protobuf.encode(NUM_MSG, intmin) > 0, true, true)
    local min_data = roundtrip(NUM_MSG, intmin)
    check_fields(self, "min", intmin, min_data)

    ------------------------------------------------------------------
    --3. num_message: 常规值往返
    ------------------------------------------------------------------
    local nor_data = roundtrip(NUM_MSG, intnor)
    check_fields(self, "nor", intnor, nor_data)

    ------------------------------------------------------------------
    --4. num_message: 最大值往返
    ------------------------------------------------------------------
    local max_data = roundtrip(NUM_MSG, intmax)
    check_fields(self, "max", intmax, max_data)

    ------------------------------------------------------------------
    --5. 缺失字段取零值(proto3 语义)
    ------------------------------------------------------------------
    local partial = roundtrip(NUM_MSG, { i32 = 5 })
    self:report("default i32", partial.i32 == 5, partial.i32, 5)
    self:report("default u32 zero", partial.u32 == 0, partial.u32, 0)
    self:report("default i64 zero", partial.i64 == 0, partial.i64, 0)
    self:report("default d32 zero", partial.d32 == 0, partial.d32, 0)

    ------------------------------------------------------------------
    --6. 编码确定性: 相同数据两次编码结果一致
    ------------------------------------------------------------------
    local e1 = protobuf.encode(NUM_MSG, intnor)
    local e2 = protobuf.encode(NUM_MSG, intnor)
    self:report("encode deterministic", e1 == e2, #e1, #e2)

    ------------------------------------------------------------------
    --7. test_message: 标量 + 嵌套 child + map + repeated + map<message>
    ------------------------------------------------------------------
    local data = {
        id = 1001014162,
        child = { id = 1, name = "hot", values = { one = "xiluo", two = "wergins" } },
        childs = {
            { id = 2, name = "laker", values = { one = "doncici", two = "james" } },
            { id = 3, name = "gsa",   values = { one = "curry",  two = "green" } },
        },
        kvs = {
            king   = { id = 4, name = "king",   values = { one = "drozan", two = "foxs" } },
            capper = { id = 5, name = "capper", values = { one = "harden", two = "lenarde" } },
        },
        custom = { role_id = "107216333761938434", name = "aaa", gender = "2", model = "3" },
        custom2 = { 1, 2, 3, 888, 666 },
    }
    local tdata = roundtrip(TEST_MSG, data)
    self:report("test_message id", tdata and tdata.id == data.id, tdata and tdata.id, data.id)
    self:report("nested child.name", tdata and tdata.child and tdata.child.name == "hot",
        tdata and tdata.child and tdata.child.name, "hot")
    self:report("nested child.map", tdata and tdata.child and tdata.child.values
        and tdata.child.values.one == "xiluo", tdata and tdata.child and tdata.child.values and tdata.child.values.one, "xiluo")
    self:report("repeated custom2 len", tdata and type(tdata.custom2) == "table" and #tdata.custom2 == 5,
        tdata and tdata.custom2 and #tdata.custom2, 5)
    local c2 = tdata and tdata.custom2 or {}
    self:report("repeated custom2[4]", c2[4] == 888, c2[4], 888)
    self:report("map custom.gender", tdata and tdata.custom and tdata.custom.gender == "2",
        tdata and tdata.custom and tdata.custom.gender, "2")
    self:report("repeated childs len", tdata and tdata.childs and #tdata.childs == 2,
        tdata and tdata.childs and #tdata.childs, 2)
    local ch2 = tdata and tdata.childs and tdata.childs[2]
    self:report("repeated childs[2].name", ch2 and ch2.name == "gsa", ch2 and ch2.name, "gsa")
    self:report("map<string,msg> kvs.king", tdata and tdata.kvs and tdata.kvs.king
        and tdata.kvs.king.name == "king", tdata and tdata.kvs and tdata.kvs.king and tdata.kvs.king.name, "king")

    ------------------------------------------------------------------
    --8. 编解码性能: 1000 次 num_message 往返
    ------------------------------------------------------------------
    local t1 = timer.time()
    for _ = 1, 1000 do
        local bytes = protobuf.encode(NUM_MSG, intnor)
        protobuf.decode(NUM_MSG, bytes)
    end
    local cost = timer.time() - t1
    self:report("protobuf perf 1000", cost >= 0, cost, ">=0")
    log_info("[protobuf perf] 1000 x (encode+decode): {} ms", cost)
end

return ProtoTest
