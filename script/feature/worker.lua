--worker.lua
import("basic/basic.lua")

local log_info      = logger.info
local log_warn      = logger.warn
local tpack         = table.pack
local tunpack       = table.unpack
local qxpcall       = quanta.xpcall
local raw_yield     = coroutine.yield
local raw_resume    = coroutine.resume
local lclock_ms     = timer.clock_ms
local ltime         = timer.time

local event_mgr     = quanta.load("event_mgr")
local co_hookor     = quanta.load("co_hookor")
local socket_mgr    = quanta.load("socket_mgr")
local update_mgr    = quanta.load("update_mgr")
local thread_mgr    = quanta.load("thread_mgr")

local TITLE         = quanta.title
local FLAG_REQ      = quanta.enum("FlagMask", "REQ")
local FLAG_RES      = quanta.enum("FlagMask", "RES")
local RPC_TIMEOUT   = quanta.enum("NetwkTime", "RPC_CALL_TIMEOUT")

local FAST_MS       = quanta.enum("PeriodTime", "FAST_MS")
local HALF_MS       = quanta.enum("PeriodTime", "HALF_MS")

--初始化核心
local function init_core()
    import("kernel/thread_mgr.lua")
    import("kernel/event_mgr.lua")
    import("kernel/config_mgr.lua")
end

--初始化网络
local function init_network()
    local max_conn = environ.number("QUANTA_MAX_CONN", 64)
    socket_mgr = luabus.create_socket_mgr(max_conn)
    quanta.socket_mgr = socket_mgr
end

--初始化统计
local function init_statis()
    import("agent/proxy_agent.lua")
    import("kernel/perfeval_mgr.lua")
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
    event_mgr = quanta.get("event_mgr")
    thread_mgr = quanta.get("thread_mgr")
    update_mgr = quanta.get("update_mgr")
end

function quanta.init()
    --核心加载
    init_core()
    --初始化基础模块
    service.init()
    --主循环
    init_coroutine()
    init_mainloop()
    init_statis()
    --网络
    init_network()
    --加载协议
    import("kernel/protobuf_mgr.lua")
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
        if work_ms > HALF_MS or io_ms > FAST_MS then
            log_warn("[worker][run] last frame too long => all:%d, net:%d)!", work_ms, io_ms)
        end
    end, "worker run err: %s")
end

--事件分发
local function notify_rpc(session_id, title, rpc, ...)
    if rpc == "on_reload" then
        log_info("[Worker][on_reload]worker:%s reload for signal !", TITLE)
        --重新加载脚本
        quanta.reload()
        --事件通知
        event_mgr:notify_trigger("on_reload")
        return
    end
    local rpc_datas = event_mgr:notify_listener(rpc, ...)
    if session_id > 0 then
        quanta.call(title, session_id, FLAG_RES, tunpack(rpc_datas))
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
    if quanta.call("master", session_id, FLAG_REQ, TITLE, rpc, ...) then
        return thread_mgr:yield(session_id, rpc, RPC_TIMEOUT)
    end
    return false, "call failed"
end

--通知主线程
quanta.send_master = function(rpc, ...)
    quanta.call("master", 0, FLAG_REQ, TITLE, rpc, ...)
end

--访问其他线程
quanta.call_worker = function(name, rpc, ...)
    local session_id = thread_mgr:build_session_id()
    if quanta.call(name, session_id, FLAG_REQ, TITLE, rpc, ...) then
        return thread_mgr:yield(session_id, rpc, RPC_TIMEOUT)
    end
    return false, "call failed"
end

--通知其他线程
quanta.send_worker = function(name, rpc, ...)
    quanta.call(name, 0, FLAG_REQ, TITLE, rpc, ...)
end