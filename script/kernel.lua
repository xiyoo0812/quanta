--kernel.lua
local ltimer = require("ltimer")

import("enum.lua")
import("class.lua")
import("mixin.lua")
import("property.lua")
import("basic/basic.lua")
import("utility/signal.lua")
import("utility/environ.lua")
import("utility/constant.lua")
import("utility/utility.lua")
import("kernel/config/config_mgr.lua")
import("kernel/core/update_mgr.lua")
import("kernel/statis/perfeval_mgr.lua")

local ltime         = ltimer.time
local log_info      = logger.info
local env_get       = environ.get
local env_number    = environ.number
local qxpcall       = quanta.xpcall
local qxpcall_quit  = quanta.xpcall_quit

local socket_mgr    = nil
local update_mgr    = quanta.get("update_mgr")

--quanta启动
function quanta.ready()
    quanta.frame = 0
    quanta.now_ms, quanta.now = ltime()
    quanta.index = env_number("QUANTA_INDEX", 1)
    quanta.deploy = env_get("QUANTA_DEPLOY", "develop")
    local service_name = env_get("QUANTA_SERVICE")
    local service_id = service.init(service_name)
    assert(service_id, "service_id not exist, quanta startup failed!")
    quanta.service = service_name
    quanta.service_id = service_id
    quanta.id = service.make_id(service_name, quanta.index)
    quanta.name = service.make_nick(service_name, quanta.index)
end

function quanta.init()
    import("utility/service.lua")
    --启动quanta
    quanta.ready()
    --初始化环境变量
    environ.init()
    --注册信号
    signal.init()
    --初始化日志
    logger.init()
    --初始化随机种子
    math.randomseed(quanta.now_ms)

    -- 网络模块初始化
    local lbus = require("luabus")
    local max_conn = env_number("QUANTA_MAX_CONN", 64)
    socket_mgr = lbus.create_socket_mgr(max_conn)
    quanta.socket_mgr = socket_mgr

    -- 初始化统计管理器
    quanta.perfeval_mgr:setup()
    import("kernel/statis/statis_mgr.lua")
    import("kernel/core/protobuf_mgr.lua")

    --初始化路由管理器
    if service.router(quanta.service_id) then
        --加载router配置
        import("kernel/core/router_mgr.lua")
        import("utility/oaim_notify.lua")
    end
    if not env_get("QUANTA_MONITOR_HOST") then
        --加载monotor
        import("agent/monitor_agent.lua")
        import("kernel/admin/netlog_mgr.lua")
    end
end

--初始化gm
function quanta.init_gm(gm_service)
    import("agent/gm_agent.lua")
    if gm_service then
        quanta.gm_agent:watch_service(gm_service)
    end
end

local function startup(startup_func)
    --初始化quanta
    quanta.init()
    --启动服务器
    startup_func()
    log_info("%s %d now startup!", quanta.service, quanta.id)
end

--启动
function quanta.startup(startup_func)
    if not quanta.init_flag then
        qxpcall_quit(startup, "quanta startup error: %s", startup_func)
        quanta.init_flag = true
    end
end

--日常更新
local function update()
    local count = socket_mgr.wait(10)
    local now_ms, now_s = ltime()
    quanta.now = now_s
    quanta.now_ms = now_ms
    --系统更新
    update_mgr:update(now_ms, count)
end

--底层驱动
quanta.run = function()
    qxpcall(update, "quanta.run error: %s")
end
