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
local sbyte     = string.byte

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

function string_ext.split_to_chars(src)
    local num = 0
    local results = {}
    if not src or type(src) ~= "string" or #src <= 0 then
        return results
    end
    local i = 1
    local src_bytes = #src
	while true do
        local curByte = sbyte(src, i)
        local byteCount
        -- [0x00, 0x7f] [0x80, 0x7ff] [0x800, 0xd7ff] [0x10000, 0x10ffff]
        if curByte > 239 then
            byteCount = 4  -- 4字节字符
        elseif curByte > 223 then
            byteCount = 3  -- 汉字
        elseif curByte > 128 then
            byteCount = 2  -- 双字节字符
        else
            byteCount = 1  -- 单字节字符
        end
        local char = ssub(src, i, i + byteCount - 1)
        num = num + 1
        results[num] = char
        i = i + byteCount
        if i > src_bytes then
            break
        end
    end

    return results
end
