--kernel.lua
import("basic/basic.lua")

local log_warn      = logger.warn
local lclock_ms     = timer.clock_ms
local ltime         = timer.time

local QuantaMode    = enum("QuantaMode")

local scheduler     = quanta.load("scheduler")
local socket_mgr    = quanta.load("socket_mgr")
local update_mgr    = quanta.load("update_mgr")

local SLOW_MS       = quanta.enum("PeriodTime", "SLOW_MS")
local HALF_MS       = quanta.enum("PeriodTime", "HALF_MS")

--初始化核心
local function init_core()
    import("kernel/thread_mgr.lua")
    import("kernel/event_mgr.lua")
    import("kernel/config_mgr.lua")
    import("kernel/perfeval_mgr.lua")
end

--初始化网络
local function init_network()
    local max_conn = environ.number("QUANTA_MAX_CONN", 64)
    socket_mgr = luabus.create_socket_mgr(max_conn)
    quanta.socket_mgr = socket_mgr
end

local function init_coroutine()
    import("basic/coroutine.lua")
    quanta.init_coroutine()
end

--初始化loop
local function init_mainloop()
    import("kernel/timer_mgr.lua")
    import("kernel/update_mgr.lua")
    import("feature/scheduler.lua")
    import("driver/webhook.lua")
    update_mgr = quanta.get("update_mgr")
    scheduler = quanta.get("scheduler")
end

function quanta.init()
    --协程初始化
    init_coroutine()
    --核心加载
    init_core()
    --初始化基础模块
    signal.init()
    environ.init()
    service.init()
    logger.init()
    --主循环
    init_mainloop()
    init_network()
    --其他模式
    if quanta.mode <= QuantaMode.ROUTER then
        --加载monitor
        if not environ.get("QUANTA_MONITOR_HOST") then
            import("agent/monitor_agent.lua")
        end
    end
    if quanta.mode == QuantaMode.SERVICE then
        --加载路由
        import("kernel/router_mgr.lua")
        --加载协议
        import("kernel/protobuf_mgr.lua")
    end
end

--启动
function quanta.startup(entry)
    quanta.frame = 0
    quanta.now_ms, quanta.clock_ms = ltime()
    quanta.now = quanta.now_ms // 1000
    --初始化随机种子
    math.randomseed(quanta.now_ms)
    --初始化quanta
    quanta.init()
    --启动服务器
    pcall(entry)
    --输出启动信息
    quanta.report("startup")
end

--底层驱动
quanta.run = function()
    local sclock_ms = lclock_ms()
    scheduler:update(sclock_ms)
    socket_mgr.wait(sclock_ms, 10)
    --系统更新
    local now_ms, clock_ms = ltime()
    update_mgr:update(scheduler, now_ms, clock_ms)
    --时间告警
    local io_ms = clock_ms - sclock_ms
    local work_ms = lclock_ms() - sclock_ms
    if work_ms > HALF_MS or io_ms > SLOW_MS then
        log_warn("[quanta][run] last frame too long => all:{}, net:{})!", work_ms, io_ms)
    end
end
