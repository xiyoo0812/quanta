--string.lua
local type = type
local load = load
local pcall     = pcall
local tostring  = tostring
local ssub      = string.sub
local sfind     = string.find
local supper    = string.upper
local slower    = string.lower
local sformat   = string.format

--------------------------------------------------------------------------------
function string_ext.parse(str)
    if str == nil then
        str = tostring(str)
    elseif type(str) ~= "string" then
        return {}
    elseif #str == 0 then
        return {}
    end
    local code, ret = pcall(load(sformat("do local _=%s return _ end", str)))
    return code and ret or {}
end


function string_ext.title(value)
    return supper(ssub(value, 1, 1)) .. ssub(value, 2, #value)
end

function string_ext.untitle(value)
    return slower(ssub(value, 1, 1)) .. ssub(value, 2, #value)
end

function string_ext.split(str, token)
    local t = {}
    while #str > 0 do
        local pos = sfind(str, token)
        if not pos then
            t[#t + 1] = str
            break
        end
        if pos > 1 then
            t[#t + 1] = ssub(str, 1, pos - 1)
        end
        str = ssub(str, pos + 1, #str)
    end
    return t
end

function string_ext.ends_with(str, ending)
    return str:sub(-#ending) == ending
end
