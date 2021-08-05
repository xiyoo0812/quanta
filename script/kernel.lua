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
import("kernel/statis/perfeval_mgr.lua")
import("kernel/basic/update_mgr.lua")

local pairs         = pairs
local ltime         = ltimer.time
local log_err       = logger.err
local env_get       = environ.get
local env_number    = environ.number

local socket_mgr    = nil
local update_mgr    = quanta.get("update_mgr")

--quanta启动
function quanta.startup()
    quanta.frame = 0
    quanta.now_ms, quanta.now = ltime()
    quanta.index = env_number("QUANTA_INDEX", 1)
    quanta.deploy = env_get("QUANTA_DEPLOY", "develop")
    local service_name = env_get("QUANTA_SERVICE")
    assert(service_name, "service not exist, quanta startup failed!")
    local service_id = service.init(service_name)
    assert(service_id, "service_id not exist, quanta startup failed!")
    quanta.service = service_name
    quanta.service_id = service_id
    quanta.id = service.make_id(service_name, quanta.index)
    quanta.name = service.make_nick(service_name, quanta.index)
    quanta.pid = quanta.get_pid()
end

function quanta.init()
    import("utility/service.lua")
    --启动quanta
    quanta.startup()
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
    import("kernel/proto/protobuf_mgr.lua")

    --加载router配置
    local config_mgr = quanta.get("config_mgr")
    config_mgr:init_table("router", "index")
    --获取路由组配置
    local router_group = service.router_group(quanta.id)
    if not router_group then
        log_err("[quanta][init] %s router group is nil, check the service_cfg.lua!", quanta.name)
        os.exit()
    end
    --初始化路由管理器
    if next(router_group) then
        import("kernel/router/router_mgr.lua")
        quanta.router_mgr:setup(router_group)
        if env_get("QUANTA_FEISHU_URL") then
            --飞书上报
            import("driver/feishu.lua")
        end
    end
    if not env_get("QUANTA_MONITOR_HOST") then
        --加载monotor
        import("kernel/monitor/monitor_agent.lua")
        import("kernel/debug/netlog_mgr.lua")
    end
end

--初始化gm
function quanta.init_gm(gm_service)
    import("kernel/admin/gm_agent.lua")
    if gm_service then
        quanta.gm_agent:watch_service(gm_service)
    end
end

--日常更新
function quanta.update()
    local count = socket_mgr.wait(10)
    local now_ms, now_s = ltime()
    quanta.now = now_s
    quanta.now_ms = now_ms
    --系统更新
    update_mgr:update(now_ms, count)
end
