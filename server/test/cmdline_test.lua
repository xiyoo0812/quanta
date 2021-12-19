--cmdline_test.lua
import("basic/cmdline.lua")

local log_debug     = logger.debug

local cmdline       = quanta.get("cmdline")

local commands = {
    {
        name = "show",
        args = "show 1234567 -10001 \"meihua\"",
        options = "player_id|integer item_id|integer item_name|string",
        data = { name = "show", player_id = 1234567, item_id = 10001, item_name = "meihua" },
    },
    {
        name = "buy",
        args = "buy 1234567 \"0x8a65dc1da45\" 3.12 {a=1,b=2,c=3,d=4}",
        options = "player_id|integer guid|string price|float info|table",
        data = { name = "buy", player_id = 1234567, guid = "0x8a65dc1da45", price = 3.12, info = {a=1,b=2,c=3,d=4} },
    },
    {
        name = "add_item",
        args = "add_item 123246545654 10101 1",
        options = "player_id|string item_id|integer count|integer",
        data = { name = "add_item", player_id = 123246545654, item_id = "10101", count = 1},
    },
}

for _, command in pairs(commands) do
    cmdline:register_command(command.name, command.options, "gm")
    local result = cmdline:parser_command(command.args)
    if result then
        for i, value in ipairs(result.args) do
            local atype = type(value)
            local name = result.info[i]
            log_debug("parse command %s args->(%s, %s[%s])", command.name, name, value, atype)
        end
    end
    local result2 = cmdline:parser_data(command.data)
    if result2 then
        for i, value in ipairs(result2.args) do
            local atype = type(value)
            local name = result2.info[i]
            log_debug("parse data %s args->(%s, %s[%s])", command.name, name, value, atype)
        end
    end
end
