--worker.lua
local log_err       = logger.err
local log_info      = logger.info
local tunpack       = table.unpack
local lnext_id      = luakit.next_id
local wcall         = quanta.call
local wupdate       = quanta.update
local wbroadcast    = quanta.broadcast
local resume_trace  = quanta.resume_trace
local extract_trace = quanta.extract_trace

local event_mgr     = quanta.get("event_mgr")
local thread_mgr    = quanta.get("thread_mgr")
local update_mgr    = quanta.get("update_mgr")

local RPC_TIMEOUT   = quanta.enum("NetwkTime", "RPC_CALL_TIMEOUT")

local FLAG_REQ      = luabus.proto_flag.REQ
local FLAG_RES      = luabus.proto_flag.RES

local THREAD_NAME   = quanta.thread

-- Worker
-------------------------------------------------------------
local Worker = singleton()
function Worker:__init()
    --事件监听
    update_mgr:attach_frame(self)
    event_mgr:add_listener(self, "on_reload")
end

function Worker:thread_name()
    return THREAD_NAME
end

--热更新
function Worker:on_reload()
    log_info("[Worker][on_reload] worker:{} reload for signal !", THREAD_NAME)
    --重新加载脚本
    quanta.reload()
    --事件通知
    event_mgr:notify_trigger("on_reload")
end

--帧更新
function Worker:on_frame(clock_ms)
    wupdate(clock_ms)
end

--线程结束
function Worker:stop()
    log_info("[quanta][stop] worker {} exit!", THREAD_NAME)
    update_mgr:quit()
end

function Worker:startup(name, entry, params, conf)
    local args = params or {}
    if not conf then
        args.entry = entry
        args.discover = "0"
    end
    local ok, wok_oe = pcall(quanta.thread_up, name, conf, args)
    if not ok then
        log_err("[Worker][startup] startup thread {} failed: {}", name, wok_oe)
    end
    return wok_oe
end

--访问其他线程任务
function Worker:broadcast(rpc, ...)
    local trace_id, span_id = extract_trace()
    wbroadcast(0, FLAG_REQ, trace_id, span_id, THREAD_NAME, rpc, ...)
end

--访问其他线程
function Worker:call(name, rpc, ...)
    local session_id = lnext_id()
    local trace_id, span_id = extract_trace()
    if wcall(name, session_id, FLAG_REQ, trace_id, span_id, THREAD_NAME, rpc, ...) then
        return thread_mgr:yield(session_id, rpc, RPC_TIMEOUT)
    end
    return false, "call failed"
end

function Worker:call_master(rpc, ...)
    return self:call("master", rpc, ...)
end

--通知其他线程
function Worker:send(name, rpc, ...)
    local trace_id, span_id = extract_trace()
    wcall(name, 0, FLAG_REQ, trace_id, span_id, THREAD_NAME, rpc, ...)
end

function Worker:send_master(rpc, ...)
    return self:send("master", rpc, ...)
end

--事件分发
local function notify_rpc(session_id, thread_name, rpc, ...)
    local rpc_datas = event_mgr:notify_listener(rpc, ...)
    if session_id > 0 then
        wcall(thread_name, session_id, FLAG_RES, 0, 0, tunpack(rpc_datas))
    end
end

--rpc调用
quanta.on_worker = function(session_id, flag, trace_id, span_id, ...)
    if flag == FLAG_REQ then
        thread_mgr:fork(notify_rpc, resume_trace(trace_id, span_id), session_id, ...)
        return
    end
    thread_mgr:response(session_id, ...)
end

quanta.scheduler = Worker()

return Worker