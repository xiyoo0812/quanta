--kernel.lua
import("basic/basic.lua")
import("utility/signal.lua")
import("utility/environ.lua")
import("utility/service.lua")
import("utility/constant.lua")
import("utility/utility.lua")
import("kernel/statis/perfeval_mgr.lua")
import("kernel/basic/thread_mgr.lua")
import("kernel/basic/timer_mgr.lua")
import("kernel/basic/wheel_map.lua")

local pairs         = pairs
local otime         = os.time
local tinsert       = table.insert
local sig_check     = signal.check
local log_err       = logger.err
local log_warn      = logger.warn
local log_info      = logger.info
local env_get       = environ.get
local env_status    = environ.status
local env_number    = environ.number
local get_time_ms   = quanta.get_time_ms
local collectgarbage= collectgarbage

local timer_mgr     = quanta.timer_mgr
local config_mgr    = quanta.config_mgr
local socket_mgr    = quanta.socket_mgr
local thread_mgr    = quanta.thread_mgr
local perfeval_mgr  = quanta.perfeval_mgr

--quanta启动
function quanta.startup()
    quanta.frame = 0
    quanta.now = otime()
    quanta.now_ms = get_time_ms()
    quanta.start_ms = get_time_ms()
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
    quanta.objects = {}
    quanta.dumps = {}
end

function quanta.init()
    --启动quanta
    quanta.startup()
    --初始化环境变量
    environ.init()
    --注册信号
    signal.init()
    --初始化日志
    logger.init()
    --初始化随机种子
    math.randomseed(quanta.start_ms)

    -- 网络模块初始化
    local lbus = require("luabus")
    local max_conn = env_number("QUANTA_MAX_CONN", 64)
    socket_mgr = lbus.create_socket_mgr(max_conn)
    quanta.socket_mgr = socket_mgr

    -- 初始化统计管理器
    perfeval_mgr:setup()
    import("kernel/statis/statis_mgr.lua")
    import("kernel/proto/protobuf_mgr.lua")

    --加载router配置
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
    end
    if not env_get("QUANTA_MONITOR_HOST") then
        --加载monotor
        import("kernel/monitor/monitor_agent.lua")
        import("kernel/debug/netlog_mgr.lua")
    end
    if env_status("QUANTA_FEISHU") then
        --飞书上报
        import("driver/feishu.lua")
    end
end

--初始化gm
function quanta.init_gm(gm_service)
    import("kernel/admin/gm_agent.lua")
    if gm_service then
        quanta.gm_agent:watch_service(gm_service)
    end
end

--添加对象到主更新循环
function quanta.join(obj)
    if obj.update then
        tinsert(quanta.objects, obj)
    end
end

--添加对象到程序结束时的dump列表
function quanta.join_dump(obj)
    if obj.dump then
        tinsert(quanta.dumps, obj)
    end
end

--垃圾回收
local last_tick = otime()
local function lua_collectgarbage()
    collectgarbage("step")
    if quanta.now - last_tick > 60 then
        last_tick = quanta.now
        collectgarbage("collect")
    end
end

--日常更新
function quanta.update()
    local count = socket_mgr.wait(10)
    local now_ms = get_time_ms()
    local escape_ms = now_ms - quanta.now_ms
    if escape_ms >= 100 then
        if escape_ms >= 400 then
            log_warn("warning escape_ms(%d) too long count(%d)!", escape_ms, count)
        end
        quanta.now = otime()
        quanta.now_ms = now_ms
        --系统更新
        timer_mgr:update(escape_ms)
        thread_mgr:update()
        --业务更新
        local frame = (now_ms - quanta.start_ms) // 100
        for _, obj in pairs(quanta.objects) do
            obj:update(frame)
        end
        quanta.frame = frame
        --垃圾回收
        if frame % 10 == 0 then
            lua_collectgarbage()
        end
        --检查信号
        if sig_check() then
            for _, obj in pairs(quanta.dumps) do
                obj:dump(true)
            end
            log_info("service quit for signal !")
            logger.close()
            quanta.run = nil
        end
    end
end
