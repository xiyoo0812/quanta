--scheduler.lua

local pcall         = pcall
local log_err       = logger.err
local tunpack       = table.unpack
local lnext_id      = luakit.next_id
local resume_trace  = quanta.resume_trace
local extract_trace = quanta.extract_trace

local wbroadcast    = worker.broadcast
local wupdate       = worker.update
local wcall         = worker.call

local FLAG_REQ      = quanta.enum("FlagMask", "REQ")
local FLAG_RES      = quanta.enum("FlagMask", "RES")
local RPC_TIMEOUT   = quanta.enum("NetwkTime", "RPC_CALL_TIMEOUT")

local event_mgr     = quanta.get("event_mgr")
local thread_mgr    = quanta.get("thread_mgr")
local update_mgr    = quanta.get("update_mgr")

local Scheduler = singleton()

function Scheduler:__init()
    --事件监听
    update_mgr:attach_quit(self)
    update_mgr:attach_frame(self)
    event_mgr:add_trigger(self, "on_reload")
    --启动
    worker.setup("quanta")
end

function Scheduler:on_reload()
    --通知woker热更新
    self:broadcast("on_reload")
end

function Scheduler:on_frame(clock_ms)
    wupdate(clock_ms)
end

function Scheduler:on_quit()
    worker.shutdown()
end

function Scheduler:startup(name, entry, params, conf)
    local args = params or {}
    if not conf then
        args.entry = entry
        args.discover = "0"
    end
    local ok, wok_oe = pcall(worker.startup, name, conf, args)
    if not ok then
        log_err("[Scheduler][startup] startup thread {} failed: {}", name, wok_oe)
    end
    return wok_oe
end

function Scheduler:stop(name)
    local ok, err = pcall(worker.stop, name)
    if not ok then
        log_err("[Scheduler][stop] stop thread {} failed: {}", name, err)
    end
end

--访问其他线程任务
function Scheduler:broadcast(rpc, ...)
    local trace_id, span_id = extract_trace()
    wbroadcast("", 0, FLAG_REQ, trace_id, span_id, "master", rpc, ...)
end

--访问其他线程任务
function Scheduler:call(name, rpc, ...)
    local session_id = lnext_id()
    local trace_id, span_id = extract_trace()
    if not wcall(name, session_id, FLAG_REQ, trace_id, span_id, "master", rpc, ... ) then
        return false, "call failed!"
    end
    return thread_mgr:yield(session_id, rpc, RPC_TIMEOUT)
end

--访问其他线程任务
function Scheduler:send(name, rpc, ...)
    local trace_id, span_id = extract_trace()
    wcall(name, 0, FLAG_REQ, trace_id, span_id, "master", rpc, ... )
end

--事件分发
local function notify_rpc(session_id, thread_name, rpc, ...)
    local rpc_datas = event_mgr:notify_listener(rpc, ...)
    if session_id > 0 then
        wcall(thread_name, session_id, FLAG_RES, tunpack(rpc_datas))
    end
end

function quanta.on_scheduler(session_id, flag, trace_id, span_id, ...)
    if flag == FLAG_REQ then
        thread_mgr:fork(notify_rpc, resume_trace(trace_id, span_id), session_id, ...)
        return
    end
    thread_mgr:response(session_id, ...)
end

quanta.scheduler = Scheduler()

return Scheduler
