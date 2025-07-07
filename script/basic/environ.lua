--environ.lua
local tonumber  = tonumber
local tunpack   = table.unpack
local sgmatch   = string.gmatch
local ssplit    = string.split
local qgetenv   = quanta.getenv
local saddr     = qstring.addr

environ = {}

local pattern = "(%a+)://([^:]-):([^@]-)@([^/]+)/?([^?]*)[%?]?(.*)"

function environ.init()
    if environ.status("QUANTA_DAEMON") then
        quanta.daemon()
    end
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

function environ.split(key, val)
    local value = qgetenv(key)
    if value then
        return tunpack(ssplit(value, val))
    end
end

function environ.table(key, str)
    return ssplit(qgetenv(key)  or "", str or ",")
end

local function parse_hosts(value)
    local hosts = {}
    local strs = ssplit(value, ",")
    for _, str in pairs(strs) do
        local k, v = saddr(str)
        if k then
            hosts[#hosts + 1] = { k, v }
        end
    end
    return hosts
end

local function parse_options(value)
    local opts = {}
    local strs = ssplit(value, "&")
    for _, str in pairs(strs) do
        local k, v = ssplit(str, "=", false)
        if k and v then
            opts[k] = v
        end
    end
    return opts
end

local function parse_driver(value)
    local driver, usn, psd, hosts, db, opts = sgmatch(value, pattern)()
    if driver then
        return {
            db = db, user = usn,
            passwd = psd, driver = driver,
            opts = parse_options(opts),
            hosts = parse_hosts(hosts)
        }
    end
end

function environ.driver(key)
    local value = qgetenv(key)
    if value then
        return parse_driver(value)
    end
end
