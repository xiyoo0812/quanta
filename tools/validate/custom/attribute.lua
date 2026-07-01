--attribute.lua

local sformat = string.format

local field_verify_funcs = {
    increase = function(output, name, field, value, value_funcs)
        if value then
            output(sformat("config %s's field '%s' is true, but it should be false!", name, field))
        end
    end,
}

local function verify_record(name, record, output, value_funcs)
    for field, value in pairs(record) do
        local verify_func = field_verify_funcs[field]
        if verify_func then
            verify_func(output, name, field, value, value_funcs)
        end
    end
    print(string.serialize(record))
end

return verify_record
