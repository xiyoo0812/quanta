--string.lua
local type = type
local load = load
local pcall     = pcall
local tostring  = tostring
local tunpack   = table.unpack
local ssub      = string.sub
local sfind     = string.find
local supper    = string.upper
local slower    = string.lower
local sformat   = string.format
local sbyte     = string.byte

string_ext = _ENV.string_ext or {}

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

function string_ext.chars(src)
    local chars = {}
    if not src then
        return chars
    end
    local pos_bytes = 1
    while pos_bytes <= #src do
        local byteCount
        local curByte = sbyte(src, pos_bytes)
        -- [0x00, 0x7f] [0x80, 0x7ff] [0x800, 0xd7ff] [0x10000, 0x10ffff]
        if curByte < 128 then
            byteCount = 1  -- 单字节字符
        elseif curByte < 222 then
            byteCount = 2  -- 双字节字符
        elseif curByte < 238 then
            byteCount = 3  -- 汉字
        else
            byteCount = 4  -- 4字节字符
        end
        local subchar = ssub(src, pos_bytes, pos_bytes + byteCount - 1)
        pos_bytes = pos_bytes + byteCount
        chars[#chars + 1] = subchar
    end
    return chars
end

--辅助接口
--------------------------------------------------------------------------------
local ssplit = string_ext.split
function string_ext.addr(value)
    local ip, port = tunpack(ssplit(value, ":"))
    return ip, tonumber(port)
end

function string_ext.protoaddr(value)
    local addr, proto = tunpack(ssplit(value, "/"))
    if addr then
        local ip, port = tunpack(ssplit(addr, ":"))
        return ip, tonumber(port), proto
    end
end
