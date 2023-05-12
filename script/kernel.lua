--kernel.lua
import("basic/basic.lua")
local ltimer        = require("ltimer")

local tpack         = table.pack
local tunpack       = table.unpack
local raw_yield     = coroutine.yield
local raw_resume    = coroutine.resume
local ltime         = ltimer.time

local QuantaMode    = enum("QuantaMode")

local co_hookor     = quanta.load("co_hookor")
local scheduler     = quanta.load("scheduler")
local socket_mgr    = quanta.load("socket_mgr")
local update_mgr    = quanta.load("update_mgr")

--初始化核心
local function init_core()
    import("kernel/thread_mgr.lua")
    import("kernel/event_mgr.lua")
    import("kernel/config_mgr.lua")
end

--初始化网络
local function init_network()
    local lbus = require("luabus")
    local max_conn = environ.number("QUANTA_MAX_CONN", 64)
    socket_mgr = lbus.create_socket_mgr(max_conn)
    quanta.socket_mgr = socket_mgr
end

--协程改造
local function init_coroutine()
    coroutine.yield = function(...)
        if co_hookor then
            co_hookor:yield()
        end
        return raw_yield(...)
    end
    coroutine.resume = function(co, ...)
        if co_hookor then
            co_hookor:yield()
            co_hookor:resume(co)
        end
        local args = tpack(raw_resume(co, ...))
        if co_hookor then
            co_hookor:resume()
        end
        return tunpack(args)
    end
    quanta.eval = function(name)
        if co_hookor then
            return co_hookor:eval(name)
        end
    end
end

--初始化loop
local function init_mainloop()
    import("kernel/timer_mgr.lua")
    import("kernel/update_mgr.lua")
    import("driver/scheduler.lua")
    update_mgr = quanta.get("update_mgr")
    scheduler = quanta.get("scheduler")
end

--初始化统计
local function init_statis()
    import("agent/proxy_agent.lua")
    import("kernel/perfeval_mgr.lua")
end

function quanta.init()
    --核心加载
    init_core()
    --初始化基础模块
    signal.init()
    environ.init()
    service.init()
    logger.init()
    --主循环
    init_coroutine()
    init_mainloop()
    init_statis()
    --加载调度器
    if quanta.mode <= QuantaMode.TOOL then
        --加载网络
        init_network()
    end
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

function quanta.hook_coroutine(hooker)
    co_hookor = hooker
    quanta.co_hookor = hooker
end

--启动
function quanta.startup(entry)
    quanta.now = 0
    quanta.frame = 0
    quanta.now_ms, quanta.clock_ms = ltime()
    --初始化随机种子
    math.randomseed(quanta.now_ms)
    --初始化quanta
    quanta.init()
    --启动服务器
    entry()
end

--底层驱动
quanta.run = function()
    if socket_mgr then
        socket_mgr.wait(10)
    end
    --系统更新
    update_mgr:update(scheduler, ltime())
    scheduler:update()
end
