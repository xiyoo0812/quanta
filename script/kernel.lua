--kernel.lua
require("ltimer")
import("basic/basic.lua")

local log_warn      = logger.warn
local lclock_ms     = timer.clock_ms
local ltime         = timer.time

local socket_mgr    = quanta.load("socket_mgr")
local update_mgr    = quanta.load("update_mgr")

local SLOW_MS       = quanta.enum("PeriodTime", "SLOW_MS")
local HALF_MS       = quanta.enum("PeriodTime", "HALF_MS")

--初始化核心
local function init_core()
    import("kernel/thread_mgr.lua")
    import("kernel/event_mgr.lua")
    import("kernel/config_mgr.lua")
end

--加载扩展库
local function init_library()
    require("lssl")
    require("luapb")
    require("ljson")
    require("lbson")
    require("lcodec")
    require("lsqlite")
end

--初始化网络
local function init_network()
    require("luabus")
    local max_conn = environ.number("QUANTA_MAX_CONN", 64)
    socket_mgr = luabus.create_socket_mgr(max_conn)
    quanta.socket_mgr = socket_mgr
    import("driver/webhook.lua")
    import("driver/loki.lua")
end

--初始化loop
local function init_mainloop()
    import("kernel/timer_mgr.lua")
    import("kernel/update_mgr.lua")
    update_mgr = quanta.get("update_mgr")
    if environ.status("QUANTA_THREAD") then
        require("lworker")
        import("feature/scheduler.lua")
    end
end

--初始化store
local function init_store()
    import("store/store_mgr.lua")
    local smode = environ.get("QUANTA_STORE")
    if smode == "cache" then
        import("store/store_cache.lua")
    elseif smode == "mongo" then
        import("store/store_mgo.lua")
    else
        import("store/store_kv.lua")
    end
end

--初始化路由和服务发现
local function init_discover()
    if environ.status("QUANTA_DISCOVER") then
        import("agent/discover_agent.lua")
        if quanta.service_name ~= "router" then
            import("kernel/router_mgr.lua")
        end
    end
end

function quanta.main()
    --核心加载
    init_core()
    --初始化基础库
    init_library()
    --初始化基础模块
    signal.init()
    environ.init()
    service.init()
    logger.init()
    --主循环
    init_mainloop()
    init_network()
    --加载服务发现
    init_discover()
    --初始化store
    init_store()
    --加载协议
    import("kernel/protobuf_mgr.lua")
end

--启动
function quanta.startup(entry)
    quanta.frame = 0
    quanta.now_ms, quanta.clock_ms = ltime()
    quanta.now = quanta.now_ms // 1000
    --初始化随机种子
    math.randomseed(quanta.now_ms)
    --初始化quanta
    quanta.main()
    --启动服务器
    pcall(entry)
    --输出启动信息
    quanta.report("startup")
end

--底层驱动
quanta.run = function()
    local sclock_ms = lclock_ms()
    socket_mgr.wait(sclock_ms, 10)
    --系统更新
    local now_ms, clock_ms = ltime()
    update_mgr:update(now_ms, clock_ms, true)
    --时间告警
    local io_ms = clock_ms - sclock_ms
    local work_ms = lclock_ms() - sclock_ms
    if work_ms > HALF_MS or io_ms > SLOW_MS then
        log_warn("[quanta][run] last frame too long => all:{}, net:{})!", work_ms, io_ms)
    end
end
