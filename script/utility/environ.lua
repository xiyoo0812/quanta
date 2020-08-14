--environ.lua
local pairs     = pairs
local tonumber  = tonumber
local ogetenv   = os.getenv
local tunpack   = table.unpack
local sformat   = string.format
local ssplit    = string_ext.split

--内存临时环境变量表
local QUANTA_ENV = {}

environ = {}

function environ.init()
    local env_file = ogetenv("QUANTA_ENV")
    if env_file then
        --exp: --env=env/router
        local custom = require(env_file)
        local index = environ.number("QUANTA_INDEX", 1)
        local custom_env = custom and custom[index]
        for key, value in pairs(custom_env or {}) do
            QUANTA_ENV[key] = value
        end
    end
    if quanta.platform == "windows" then
        QUANTA_ENV.QUANTA_DAEMON = 0
        QUANTA_ENV.QUANTA_STATIS = 1
        QUANTA_ENV.QUANTA_PERFEVAL = 1
    end
    print("---------------------environ value dump-------------------")
    for key, _ in pairs(QUANTA_ENV) do
        print(sformat("%s ----> %s", key, environ.get(key)))
    end
    print("----------------------------------------------------------")
end

function environ.get(key, def)
    return QUANTA_ENV[key] or ogetenv(key) or def
end

function environ.number(key, def)
    return tonumber(QUANTA_ENV[key] or ogetenv(key) or def)
end

function environ.status(key)
    return (tonumber(QUANTA_ENV[key] or ogetenv(key) or 0) > 0)
end

function environ.addr(key)
    local addr = QUANTA_ENV[key] or ogetenv(key)
    if addr then
        local ip, port = tunpack(ssplit(addr, ":"))
        return ip, tonumber(port)
    end
end

function environ.colon(key)
    local value = QUANTA_ENV[key] or ogetenv(key)
    if value then
        local arg1, arg2 = tunpack(ssplit(value, ":"))
        return tonumber(arg1), tonumber(arg2)
    end
end

function environ.table(key, str)
    return ssplit(QUANTA_ENV[key] or ogetenv(key) or "", str or ",")
end
