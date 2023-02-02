--worker.lua
import("basic/basic.lua")
import("kernel/config_mgr.lua")
local lcodec        = require("lcodec")
local ltimer        = require("ltimer")

local pcall         = pcall
local log_err       = logger.err
local tpack         = table.pack
local tunpack       = table.unpack
local lencode       = lcodec.encode_slice
local ldecode       = lcodec.decode_slice
local ltime         = ltimer.time

local event_mgr     = quanta.get("event_mgr")
local socket_mgr    = quanta.load("socket_mgr")
local update_mgr    = quanta.load("update_mgr")
local thread_mgr    = quanta.load("thread_mgr")

local TITLE         = quanta.get_title()
local FLAG_REQ      = quanta.enum("FlagMask", "REQ")
local FLAG_RES      = quanta.enum("FlagMask", "RES")
local RPC_TIMEOUT   = quanta.enum("NetwkTime", "RPC_CALL_TIMEOUT")

--初始化网络
local function init_network()
    local lbus = require("luabus")
    local max_conn = environ.number("QUANTA_MAX_CONN", 64)
    socket_mgr = lbus.create_socket_mgr(max_conn)
    quanta.socket_mgr = socket_mgr
end

--初始化loop
local function init_mainloop()
    import("kernel/thread_mgr.lua")
    import("kernel/timer_mgr.lua")
    import("kernel/update_mgr.lua")
    thread_mgr = quanta.get("thread_mgr")
    update_mgr = quanta.get("update_mgr")
end

function quanta.init()
    --初始化基础模块
    service.init()
    --主循环
    init_mainloop()
    --网络
    init_network()
    --加载协议
    import("kernel/protobuf_mgr.lua")
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
        socket_mgr.wait(50)
    end
    quanta.update()
    --系统更新
    update_mgr:update(ltime())
end

--事件分发
local function notify_rpc(session_id, rpc, ...)
    local rpc_datas = event_mgr:notify_listener(rpc, ...)
    if session_id > 0 then
        quanta.call(lencode(session_id, FLAG_RES, tunpack(rpc_datas)))
    end
end

--事件分发
local function worker_rpc(session_id, flag, ...)
    if flag == FLAG_REQ then
        notify_rpc(session_id, ...)
    else
        thread_mgr:response(session_id, ...)
    end
end

--rpc调用
quanta.on_worker = function(slice)
    local rpc_res = tpack(pcall(ldecode, slice))
    if not rpc_res[1] then
        log_err("[quanta][on_worker] decode failed %s!", rpc_res[2])
        return
    end
    thread_mgr:fork(function()
        worker_rpc(tunpack(rpc_res, 2))
    end)
end

--访问主线程任务
quanta.call_master = function(rpc, ...)
    local session_id = thread_mgr:build_session_id()
    quanta.call(lencode(session_id, FLAG_REQ, TITLE, rpc, ...))
    return thread_mgr:yield(session_id, "call_master", RPC_TIMEOUT)
end

--访问其他线程任务
quanta.send_master = function(rpc, ...)
    quanta.call(lencode(0, FLAG_REQ, "", rpc, ...))
end
