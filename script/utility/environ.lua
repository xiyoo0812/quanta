--environ.lua
local pairs       = pairs
local tonumber    = tonumber
local ogetenv     = os.getenv
local tunpack     = table.unpack
local sformat     = string.format
local ssplit      = string_ext.split

local ENV = {
    --app id
    ENV_GAME_APP_ID         = 1000,
    --area id
    ENV_GAME_AREA_ID        = 1000,
    -- 小区 ID
    ENV_PARTITION_ID        = "1",
    --本机ip
    ENV_HOST_ADDR_IP        = "127.0.0.1",
    -- mongo group
    ENV_MONGO_GROUP         = "1",
    -- mysql group
    ENV_MYSQL_GROUP         = "1",
    -- 最大连接数
    ENV_MAX_CONNECTION      = "4096",
    -- daemon
    ENV_DAEMON_STATE        = "0",
    -- 统计开关
    ENV_STATIS_STATE        = "0",
    -- 性能统计开关
    ENV_PERFEVAL_STATE      = "0",
    -- 飞书开关
    ENV_FEISHU_STATE        = "0",
    -- 日志等级
    ENV_LOGGER_LEVEL        = "1",
    -- 日志路径
    ENV_LOGGER_PATH         = "/var/quanta/logs",
    -- coredump路径
    ENV_COREDUMP_PATH       = "/var/quanta/core",
}

environ = {}

function environ.init(options)
    if options.env then
        --exp: --env=env/router
        local custom = require(options.env)
        local index = tonumber(options.index)
        local custom_env = custom and custom[index]
        for key, value in pairs(custom_env or {}) do
            ENV[key] = value
        end
    end
    if quanta.platform == "windows" then
        ENV.ENV_LOGGER_PATH = "logs"
        ENV.ENV_DAEMON_STATE = 0
        ENV.ENV_STATIS_STATE = 1
        ENV.ENV_PERFEVAL_STATE = 1
    end
    print("---------------------environ value dump-------------------")
    for key, _ in pairs(ENV) do
        print(sformat("%s ----> %s", key, environ.get(key)))
    end
    print("----------------------------------------------------------")
end

function environ.get(key)
    return ogetenv(key) or ENV[key]
end

function environ.number(key)
    return tonumber(ogetenv(key) or ENV[key] or 0)
end

function environ.status(key)
    return (tonumber(ogetenv(key) or ENV[key] or 0) > 0)
end

function environ.addr(key)
    local addr = ogetenv(key) or ENV[key]
    if addr then
        return tunpack(ssplit(addr, ":"))
    end
end

function environ.table(key, str)
    return ssplit(ogetenv(key) or ENV[key] or "", str or ",")
end
