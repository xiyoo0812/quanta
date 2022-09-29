--environ.lua
local tonumber  = tonumber
local qgetenv   = quanta.getenv
local tunpack   = table.unpack
local saddr     = qstring.addr
local ssplit    = qstring.split
local protoaddr = qstring.protoaddr

environ = {}

function environ.init()
    if environ.status("QUANTA_DAEMON") then
        quanta.daemon()
    end
    quanta.mode = environ.number("QUANTA_MODE", 1)
end

function environ.get(key, def)
    return qgetenv(key) or def
end

function environ.number(key, def)
    return tonumber(qgetenv(key) or def)
end

function environ.status(key)
    return (tonumber(qgetenv(key) or 0) > 0)
end

function environ.addr(key)
    local value = qgetenv(key)
    if value then
        return saddr(value)
    end
end

function environ.protoaddr(key)
    local value = qgetenv(key)
    if value then
        return protoaddr(value)
    end
end

function environ.split(key, val)
    local value = qgetenv(key)
    if value then
        return tunpack(ssplit(value, val))
    end
end

function environ.table(key, str)
    return ssplit(qgetenv(key)  or "", str or ",")
end
