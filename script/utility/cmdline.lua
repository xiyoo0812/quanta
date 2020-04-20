--cmdline.lua
local lpeg = require("lpeg")
local slower = string.lower

local lpeg_c = lpeg.C
local lpeg_p = lpeg.P
local lpeg_r = lpeg.R
local lpeg_s = lpeg.S
local lpeg_v = lpeg.V
local lpeg_ct = lpeg.Ct
local lpeg_cg = lpeg.Cg
local lpeg_match = lpeg.match

local space  = lpeg_s(" \t")
local blank = space ^ 1
local blank0 = space ^ 0

--匹配双引号字符串
local charset = (lpeg_p(1) - lpeg_s"\\\"") + (lpeg_s"\\" * lpeg_s"\\\"")
local pstr = lpeg_p("\"") * lpeg_cg(charset^0) * "\""

--匹配token, token为非双引号字符串及table的参数
local ptoken = lpeg_c((lpeg_p(1) - (space + lpeg_s"\\\"{}"))^1)

--匹配变量名和命令名
local letter = lpeg_r"az" + lpeg_r"AZ"+ lpeg_s"_" + lpeg_s"."
local cmdname = letter * (letter  + lpeg_r"09") ^ 0
local varname = cmdname

--匹配table
--匹配表中的字符串值，不提取
local tstr = blank0 * lpeg_p("\"") * charset^0 * "\"" * blank0
--匹配数字
local hex = (lpeg_p"0x" + "0X")*(lpeg_r"09"+lpeg_r"af"+lpeg_r"AF")^1
local decimal = (lpeg_r"19" * lpeg_r"09"^0) + lpeg_p("0")
local tnum = (hex + decimal) * blank0
local tseparator = lpeg_p"," * blank0
local tequal     = lpeg_p"=" * blank0
local tkey = (varname + lpeg_p"[" * (tstr+tnum) * lpeg_p"]") * blank0
local ptable = lpeg_c(lpeg_p{
    "T";
    T=lpeg_p"{" * lpeg_v"titems" * lpeg_p"}",
    titems = (lpeg_v"titem" * tseparator)^0 * ((lpeg_v"titem")^-1),
    titem = (tnum + tstr + lpeg_v"T" + (tkey * tequal * (tstr + tnum + lpeg_v"T" + lpeg_p"true" + lpeg_p"false"))) * blank0
})

--gm命令的参数有三种类型:字符串, token, table
local param = ptoken + pstr + ptable
local params = lpeg_ct((param * blank)^0 * param^-1)

--匹配gm命令
local all = lpeg_ct(lpeg_cg(cmdname, "name")*(blank*lpeg_cg(params, "args"))^-1*blank0*lpeg_p(-1))

local function cmd_parser(cmd)
    local ret = lpeg_match(all, cmd)
    if ret then
        ret.name = slower(ret.name)
    end
    return ret
end

--[[
local test_cmd = {
 "help",
 "group.1.help move",
 "move name 123 456",
 "moveto 0x678 0x774",
 "update \"无比蛋疼\" {level=85, hp=0x1118, name=\"what happen\"}",
 "set {100, 500,\"aaa\", x=5, y=6}",
}

function testparser()
    for _,v in ipairs(test_cmd) do
        local ret = cmd_parser(v)
        print("testparser:", serialize(ret))
    end
end

testparser()
]]

return cmd_parser
