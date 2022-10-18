--worker.lua
import("basic/basic.lua")
import("kernel/config_mgr.lua")
local lcodec        = require("lcodec")
local ltimer        = require("ltimer")

local pcall         = pcall
local log_err       = logger.err
local tpack         = table.pack
local tunpack       = table.unpack
local raw_yield     = coroutine.yield
local raw_resume    = coroutine.resume
local lencode       = lcodec.encode_slice
local ldecode       = lcodec.decode_slice
local ltime         = ltimer.time

local event_mgr     = quanta.get("event_mgr")
local co_hookor     = quanta.load("co_hookor")
local socket_mgr    = quanta.load("socket_mgr")
local update_mgr    = quanta.load("update_mgr")

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
    import("kernel/thread_mgr.lua")
    import("kernel/timer_mgr.lua")
    import("kernel/update_mgr.lua")
    update_mgr = quanta.get("update_mgr")
end

function quanta.init()
    --初始化基础模块
    service.init()
    --主循环
    init_coroutine()
    init_mainloop()
    --加载统计
    import("kernel/statis_mgr.lua")
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
    if socket_mgr then
        socket_mgr.wait(100)
    end
    quanta.update()
    --系统更新
    update_mgr:update(ltime())
end

--事件分发
local function worker_rpc(session_id, rpc, ...)
    local rpc_datas = event_mgr:notify_listener(rpc, ...)
    if session_id > 0 then
        quanta.callback(lencode(session_id, tunpack(rpc_datas)))
    end
end

--rpc调用
quanta.on_worker = function(slice)
    local rpc_res = tpack(pcall(ldecode, slice))
    if not rpc_res[1] then
        log_err("[quanta][on_worker] decode failed %s!", rpc_res[2])
        return
    end
    worker_rpc(tunpack(rpc_res, 2))
end

--唤醒主线程
function quanta.wakeup_main(...)
    quanta.wakeup(lencode(...))
end
