--cmdlist.lua
local lpeg = require("lpeg")
local type = type
local load = load
local ipairs = ipairs
local tonumber = tonumber
local tostring = tostring
local slower = string.lower

local lpeg_c = lpeg.C
local lpeg_p = lpeg.P
local lpeg_r = lpeg.R
local lpeg_s = lpeg.S
local lpeg_ct = lpeg.Ct
local lpeg_cg = lpeg.Cg
local lpeg_match = lpeg.match

local newline = (lpeg_s"#" * (lpeg_p(1) - lpeg_s"\r\n")^0)^-1 * lpeg_s"\r\n"
local whitespace = lpeg_s" \t" + newline
local blank = whitespace ^ 1
local blank0 = whitespace ^ 0
local decimal = (lpeg_r"19" * lpeg_r"09"^0) + lpeg_p("0")
local letter = lpeg_r"az" + lpeg_r"AZ" + lpeg_s"_"
local word = letter * (letter + lpeg_r"09") ^ 0
local types = lpeg_p("string") + lpeg_p("number") + lpeg_p("table")

local cmd    = lpeg_cg(word, "name") * (blank0 * "|" * blank0 * lpeg_cg(decimal, "min_arg_count"))^0
local param  = lpeg_ct(lpeg_cg(word, "name") * blank0 * "|" * blank0 * lpeg_cg(types, "type"))
local params = lpeg_ct((param*blank)^0)

--匹配双引号字符串
local charset = (lpeg_p(1) - lpeg_s"\\\"") + (lpeg_s"\\" * lpeg_s"\\\"")
local desc = (lpeg_p("\"") * lpeg_cg(charset^0) * "\"")^0
local notify_params = "[" * (lpeg_c(word) * blank0)^0 * "]"

local command = lpeg_ct(cmd * blank * lpeg_cg(params, "args") * blank0 *
    lpeg_cg(desc, "desc") * blank0 * (lpeg_cg(lpeg_ct(notify_params), "tags"))^-1)
local commands = lpeg_ct((command*blank0)^0)
local group = lpeg_ct(lpeg_cg(word , "group") * blank0 * "{" * blank0 * lpeg_cg(commands, "commands") * blank0 * "}")
local groups = lpeg_ct((group*blank0)^1)
local all = blank0 * groups * blank0

local function totable(v)
    local cc = load("return " .. v)
    if cc then
        local t = cc()
        if type(t) == "table" then
            return t
        end
    end
    return nil
end

local function get_unpack_fun(t)
    return function (v)
        if type(v) == t then
            return v
        end
        if t == "number" then
            return tonumber(v)
        elseif t == "string" then
            return tostring(v)
        elseif t == "table" then
            return totable(v)
        else
            return tostring(v)
        end
    end
end

local function args_parser(argsd)
    local args = lpeg_match(params, argsd .. " ")
    for _, arg in pairs(args) do
        arg.unpack = get_unpack_fun(arg.type)
    end
    return args
end

local function cmdlist_parser(list)
    local cmd_list = {}
    local group_list = {}
    local grps = lpeg_match(all, list)
    for _,v in ipairs(grps) do
        local grp = v["group"]
        local cmds = v["commands"]

        local cs = {}
        for _,vv in ipairs(cmds) do
            local name = slower(vv.name)
            local c = {}
            --c.normal_name = grp .. "." .. name
            c.normal_name = name
            c.name = name
            c.group = grp
            for _, arg in ipairs(vv.args) do
                arg.unpack = get_unpack_fun(arg.type)
            end
            c.args = vv.args
            c.tags = vv.tags
            if vv.desc and #vv.desc > 0 then
                c.desc = vv.desc
            else
                c.desc = "该命令无使用说明"
            end
            cmd_list[name] = c
            cs[#cs+1] = name
        end
        group_list[grp] = cs
    end
    return cmd_list, group_list
end

--[==[
list = [[
base {
    move playerid|string x|number y|number z|number
    moveto x|number y|number z|number
    change x|number y|number z|number
}
]]
local a, b  = cmdlist_parser(list)
for _, v in pairs(a) do
    print("cmdlist_parser", serialize(v), serialize(b))
end
]==]

return args_parser, cmdlist_parser
