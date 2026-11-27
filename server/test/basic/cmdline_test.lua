-- cmdline_test.lua
import("basic/cmdline.lua")

local cmdline      = quanta.get("cmdline")

local TestCase     = import("test/case.lua")
local CmdlineTest  = class(TestCase)

--用带前缀的唯一名字, 避免和其它用例/服务注册的命令重名
local CMDS = {
    {
        name = "ct_show",
        args = "ct_show 1234567 -10001 \"meihua\"",
        options = "player_id|integer item_id|integer item_name|string",
        data = { name = "ct_show", player_id = 1234567, item_id = -10001, item_name = "meihua" },
        expect = { "ct_show", 1234567, -10001, "meihua" },
    },
    {
        name = "ct_buy",
        args = "ct_buy 1234567 \"0x8a65dc1da45\" 3.12 {a=1,b=2}",
        options = "player_id|integer guid|string price|float info|table",
        data = { name = "ct_buy", player_id = 1234567, guid = "0x8a65dc1da45", price = 3.12, info = { a = 1, b = 2 } },
    },
    {
        name = "ct_items",
        args = "ct_items 123246545654 10101 1",
        options = "player_id|string item_id|string count|integer",
        data = { name = "ct_items", player_id = "123246545654", item_id = "10101", count = 1 },
    },
}

function CmdlineTest:setup()
    for _, cmd in ipairs(CMDS) do
        cmdline:register_command(cmd.name, cmd.options, "gm test", "gm")
    end
end

function CmdlineTest:run()
    ------------------------------------------------------------------
    --1. register_command: 注册成功, 重复注册返回 false
    ------------------------------------------------------------------
    self:report("registered commands", cmdline.commands.ct_show ~= nil and cmdline.commands.ct_buy ~= nil,
        true, true)
    local dup = cmdline:register_command("ct_show", "x|integer", "gm test", "gm")
    self:report("duplicate register rejected", dup == false, dup, false)

    ------------------------------------------------------------------
    --2. parser_command: 字符串 -> 类型化参数
    ------------------------------------------------------------------
    local r1 = cmdline:parser_command(CMDS[1].args)
    self:report("parse command ok", r1 ~= nil, r1 ~= nil, true)
    if r1 then
        self:report("parse name", r1.name == "ct_show", r1.name, "ct_show")
        self:report("parse args count", #r1.args == 4, #r1.args, 4)
        self:report("parse integer", r1.args[2] == 1234567, r1.args[2], 1234567)
        self:report("parse negative integer", r1.args[3] == -10001, r1.args[3], -10001)
        self:report("parse string", r1.args[4] == "meihua", r1.args[4], "meihua")
        self:report("parse info", r1.info[2] == "player_id" and r1.info[4] == "item_name", true, true)
    end

    ------------------------------------------------------------------
    --3. parser_command: float / table / string 类型
    ------------------------------------------------------------------
    local r2 = cmdline:parser_command(CMDS[2].args)
    self:report("parse float/table ok", r2 ~= nil, r2 ~= nil, true)
    if r2 then
        self:report("parse float", r2.args[4] == 3.12, r2.args[4], 3.12)
        self:report("parse table", type(r2.args[5]) == "table" and r2.args[5].a == 1 and r2.args[5].b == 2,
            r2.args[5] and r2.args[5].a, 1)
        self:report("parse guid string", r2.args[3] == "0x8a65dc1da45", r2.args[3], "0x8a65dc1da45")
    end

    ------------------------------------------------------------------
    --4. parser_data: table -> 类型化参数(与 parser_command 结果一致)
    ------------------------------------------------------------------
    local d1 = cmdline:parser_data(CMDS[1].data)
    self:report("parse data ok", d1 ~= nil, d1 ~= nil, true)
    if d1 then
        self:report("data args count", #d1.args == 4, #d1.args, 4)
        self:report("data integer", d1.args[2] == 1234567, d1.args[2], 1234567)
        self:report("data equals command", d1.args[4] == CMDS[1].expect[4], d1.args[4], CMDS[1].expect[4])
    end

    ------------------------------------------------------------------
    --5. 错误路径: 未注册命令 / 缺参数
    ------------------------------------------------------------------
    local bad = cmdline:parser_command("ct_not_registered 1")
    self:report("unknown command rejected", bad == nil, bad, nil)
    local missing = cmdline:parser_data({ name = "ct_show", player_id = 1 })
    self:report("missing arg rejected", missing == nil, missing, nil)
end

return CmdlineTest
