--environ.lua
local pairs       = pairs
local tonumber    = tonumber
local ogetenv     = os.getenv
local tunpack     = table.unpack
local sformat     = string.format
local ssplit      = lua_extend.split
local def_env_cfg = import("config/default_env.lua")
local get_name    = service.get_name

local ENV = {
    --app id
    ENV_GAME_APP_ID         = 1000,
    --area id
    ENV_GAME_AREA_ID        = 1000,
    --本机ip
    ENV_HOST_ADDR_IP        = "127.0.0.1",
    --dir 监听地址
    ENV_DIR_LISTEN_ADDR     = "0.0.0.0:20013",
    --lobby 监听地址
    ENV_LOBBY_LISTEN_ADDR   = "0.0.0.0:20015",
    --lobby 发送地址
    ENV_LOBBY_CLIENT_ADDR   = "127.0.0.1:20015",
    --router 监听地址
    ENV_ROUTER_LISTEN_ADDR  = "0.0.0.0:9001",
    --monitor http地址
    ENV_MONITOR_HTTP_ADDR   = "0.0.0.0:9101",
    --monitor 监听地址
    ENV_MONITOR_LISTEN_ADDR = "0.0.0.0:9201",
    --monitor 地址
    ENV_MONITOR_ADDR        = "127.0.0.1:9201",
    --dsa 监听地址
    ENV_DSA_LISTEN_ADDR     = "0.0.0.0:9301",
    --ds 绑定端口范围
    ENV_DS_OUT_PORT_RANGE   = "7000:8000",
    -- 平台监听地址
    ENV_PLATC_LISTEN_ADDR   = "0.0.0.0:8888",
    ENV_PLATC_CLIENT_ADDR   = "127.0.0.1:8888",
    ENV_PLATS_LISTEN_ADDR   = "0.0.0.0:8889",
    ENV_PLATS_CLIENT_ADDR   = "127.0.0.1:8889",
    -- mongo group
    ENV_MONGO_GROUP         = "1",
    -- mysql group
    ENV_MYSQL_GROUP         = "1",
    -- router group
    ENV_ROUTER_GROUP        = "1",
    -- 小区 ID
    ENV_PARTITION_ID        = "1",
    -- DATA COUNT
    ENV_DATA_COUNT          = "1",
    -- DATA HASH
    ENV_DATA_HASH           = "1",
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
    -- 后台管理系统HOST
    ENV_WEBADMIN_HOST       = "127.0.0.1:8080",
    -- DS Path
    ENV_DS_PATH             = "E:\\PaperMan_DS\\WindowsServer\\PM\\Binaries\\Win64\\PMServer.exe",
}

environ = {}

function environ.init(options)
    -- 合并公共环境变量
    for key, value in pairs(def_env_cfg.common or {}) do
        ENV[key] = value
    end
    -- 合并类型公共环境变量
    for key, value in pairs(def_env_cfg[get_name(quanta.group)] or {}) do
        ENV[key] = value
    end
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
