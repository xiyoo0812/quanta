--worker.lua
import("basic/basic.lua")

local log_info      = logger.info
local log_warn      = logger.warn
local tunpack       = table.unpack
local qxpcall       = quanta.xpcall
local wcall         = quanta.call
local lclock_ms     = timer.clock_ms
local ltime         = timer.time

local event_mgr     = quanta.load("event_mgr")
local socket_mgr    = quanta.load("socket_mgr")
local update_mgr    = quanta.load("update_mgr")
local thread_mgr    = quanta.load("thread_mgr")

local TITLE         = quanta.title
local FLAG_REQ      = quanta.enum("FlagMask", "REQ")
local FLAG_RES      = quanta.enum("FlagMask", "RES")
local RPC_TIMEOUT   = quanta.enum("NetwkTime", "RPC_CALL_TIMEOUT")

local SLOW_MS       = quanta.enum("PeriodTime", "SLOW_MS")
local HALF_MS       = quanta.enum("PeriodTime", "HALF_MS")

--初始化核心
local function init_core()
    quanta.init_coroutine()
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

local function init_listener()
    event_mgr:add_listener(quanta, "on_reload")
end

--初始化loop
local function init_mainloop()
    import("kernel/timer_mgr.lua")
    import("kernel/update_mgr.lua")
    import("driver/webhook.lua")
    event_mgr = quanta.get("event_mgr")
    thread_mgr = quanta.get("thread_mgr")
    update_mgr = quanta.get("update_mgr")
end

function quanta.main()
    --核心加载
    init_core()
    --初始化基础模块
    service.init()
    --主循环
    init_mainloop()
    --网络
    init_network()
    --事件
    init_listener()
    --加载协议
    import("kernel/protobuf_mgr.lua")
end

--热更新
quanta.on_reload = function()
    log_info("[quanta][on_reload] worker:{} reload for signal !", TITLE)
    --重新加载脚本
    quanta.reload()
    --事件通知
    event_mgr:notify_trigger("on_reload")
end

--启动
function quanta.startup(entry)
    quanta.now = 0
    quanta.frame = 0
    quanta.now_ms, quanta.clock_ms = ltime()
    --初始化随机种子
    math.randomseed(quanta.now_ms)
    --初始化quanta
    quanta.main()
    --注册系统事件
    --启动服务器
    entry()
end

--底层驱动
quanta.run = function()
    --系统更新
    qxpcall(function()
        local sclock_ms = lclock_ms()
        quanta.update(sclock_ms)
        socket_mgr.wait(sclock_ms, 10)
        local now_ms, clock_ms = ltime()
        update_mgr:update(nil, now_ms, clock_ms)
        --时间告警
        local io_ms = clock_ms - sclock_ms
        local work_ms = lclock_ms() - sclock_ms
        if work_ms > HALF_MS or io_ms > SLOW_MS then
            log_warn("[worker][run] last frame too long => all:{}, net:{})!", work_ms, io_ms)
        end
    end, "worker run err: {}")
end

--事件分发
local function notify_rpc(session_id, title, rpc, ...)
    local rpc_datas = event_mgr:notify_listener(rpc, ...)
    if session_id > 0 then
        wcall(title, session_id, FLAG_RES, tunpack(rpc_datas))
    end
end

--rpc调用
quanta.on_worker = function(session_id, flag, ...)
    if flag == FLAG_REQ then
        thread_mgr:fork(notify_rpc, session_id, ...)
        return
    end
    thread_mgr:response(session_id, ...)
end

--访问主线程
quanta.call_master = function(rpc, ...)
    local session_id = thread_mgr:build_session_id()
    if wcall("master", session_id, FLAG_REQ, TITLE, rpc, ...) then
        return thread_mgr:yield(session_id, rpc, RPC_TIMEOUT)
    end
    return false, "call failed"
end

--通知主线程
quanta.send_master = function(rpc, ...)
    wcall("master", 0, FLAG_REQ, TITLE, rpc, ...)
end

--访问其他线程
quanta.call_worker = function(name, rpc, ...)
    local session_id = thread_mgr:build_session_id()
    if wcall(name, session_id, FLAG_REQ, TITLE, rpc, ...) then
        return thread_mgr:yield(session_id, rpc, RPC_TIMEOUT)
    end
    return false, "call failed"
end

--通知其他线程
quanta.send_worker = function(name, rpc, ...)
    wcall(name, 0, FLAG_REQ, TITLE, rpc, ...)
end