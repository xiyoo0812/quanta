--string.lua
local type      = type
local load      = load
local pcall     = pcall
local tostring  = tostring
local tunpack   = table.unpack
local ssub      = string.sub
local sbyte     = string.byte
local sfind     = string.find
local sgsub     = string.gsub
local sformat   = string.format
local sgmatch   = string.gmatch

qstring = {}

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
local ssplit = string.split
function qstring.addr(value)
    local ip, port = tunpack(ssplit(value, ":"))
    return ip, tonumber(port)
end

local saddr = qstring.addr
function qstring.url(url)
    if not url then
        return
    end
    local scheme, addr = sgmatch(url, "(.+)://(.+)")()
    if not scheme then
        return
    end
    local host, port, path
    local i, j = addr:find("/")
    if not i then
        path = "/"
        host, port = saddr(addr)
    else
        path = addr:sub(j)
        host, port = saddr(addr:sub(1, i - 1))
    end
    if not port then
        port = scheme == "https" and 443 or 80
    end
    return scheme, host, port, path
end
