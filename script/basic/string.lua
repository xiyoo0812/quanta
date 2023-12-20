--string.lua
local type = type
local load = load
local pcall     = pcall
local tostring  = tostring
local tunpack   = table.unpack
local ssub      = string.sub
local sfind     = string.find
local sgsub     = string.gsub
local supper    = string.upper
local slower    = string.lower
local sformat   = string.format
local sbyte     = string.byte

qstring = _ENV.qstring or {}

--------------------------------------------------------------------------------
function qstring.parse(str)
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

function qstring.trim(value)
    return sgsub(value, " ", "")
end

function qstring.title(value)
    return supper(ssub(value, 1, 1)) .. ssub(value, 2, #value)
end

function qstring.untitle(value)
    return slower(ssub(value, 1, 1)) .. ssub(value, 2, #value)
end

function qstring.count(value, chl)
    local c, p = 0, 0
    while true do
        p = sfind(value, chl, p + 1, 0)
        if not p then
            break
        end
        c = c + 1
    end
    return c
end

function qstring.split(str, token)
    local pos, t = 0, {}
    if #str > 0 then
        for st, sp in function() return sfind(str, token, pos, true) end do
            if st > 1 then
                t[#t + 1] = ssub(str, pos, st - 1)
            end
            pos = sp + 1
        end
        if pos <= #str then
            t[#t + 1] = ssub(str, pos)
        end
    end
    return t
end

function qstring.start_with(str, start)
    return str:sub(1, #start) == start
end

function qstring.ends_with(str, ending)
    return str:sub(-#ending) == ending
end

function qstring.chars(src)
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
local ssplit = qstring.split
function qstring.addr(value)
    local ip, port = tunpack(ssplit(value, ":"))
    return ip, tonumber(port)
end

function qstring.protoaddr(value)
    local addr, proto = tunpack(ssplit(value, "/"))
    if addr then
        local ip, port = tunpack(ssplit(addr, ":"))
        return ip, tonumber(port), proto
    end
end

function qstring.usplit(str, token)
    return tunpack(ssplit(str, token))
end
