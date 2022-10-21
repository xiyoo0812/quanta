--kernel.lua
import("basic/basic.lua")
local ltimer = require("ltimer")

local socket_mgr    = nil
local update_mgr    = nil
local ltime         = ltimer.time

local QuantaMode    = enum("QuantaMode")

--初始化网络
local function init_network()
    local lbus = require("luabus")
    local max_conn = environ.number("QUANTA_MAX_CONN", 64)
    socket_mgr = lbus.create_socket_mgr(max_conn)
    quanta.socket_mgr = socket_mgr
end

--初始化路由
local function init_router()
    import("kernel/router_mgr.lua")
    import("driver/webhook.lua")
end

--初始化loop
local function init_mainloop()
    import("kernel/thread_mgr.lua")
    import("kernel/timer_mgr.lua")
    import("kernel/update_mgr.lua")
    update_mgr = quanta.get("update_mgr")
end

function quanta.init()
    --初始化基础模块
    signal.init()
    environ.init()
    service.init()
    logger.init()
    --主循环
    init_mainloop()
    --网络
    if quanta.mode <= QuantaMode.TOOL then
        --加载统计
        import("kernel/perfeval_mgr.lua")
        import("kernel/statis_mgr.lua")
        init_network()
    end
    if quanta.mode <= QuantaMode.ROUTER then
        --加载monotor
        if not environ.get("QUANTA_MONITOR_HOST") then
            import("agent/monitor_agent.lua")
            import("kernel/netlog_mgr.lua")
        end
    end
    if quanta.mode == QuantaMode.SERVICE then
        --加载路由
        init_router()
        --加载协议
        import("kernel/protobuf_mgr.lua")
    end
end

function quanta.init_gm()
    import("agent/gm_agent.lua")
end

--启动
function quanta.startup(entry)
    quanta.now = 0
    quanta.frame = 0
    quanta.yield = coroutine.yield
    quanta.resume = coroutine.resume
    quanta.running = coroutine.running
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
    update_mgr:update(ltime())
end
