--scheduler.lua

local pcall         = pcall
local log_err       = logger.err
local tunpack       = table.unpack

local wbroadcast    = worker.broadcast
local wupdate       = worker.update
local wcall         = worker.call

local FLAG_REQ      = quanta.enum("FlagMask", "REQ")
local FLAG_RES      = quanta.enum("FlagMask", "RES")
local RPC_TIMEOUT   = quanta.enum("NetwkTime", "RPC_CALL_TIMEOUT")

local event_mgr     = quanta.get("event_mgr")
local thread_mgr    = quanta.get("thread_mgr")

local Scheduler = singleton()

function Scheduler:__init()
    worker.setup("quanta", environ.get("QUANTA_SANDBOX"))
end

function Scheduler:quit()
    worker.shutdown()
end

function Scheduler:update(clock_ms)
    wupdate(clock_ms)
end

function Scheduler:startup(name, entry)
    local ok, err = pcall(worker.startup, name, entry)
    if not ok then
        log_err("[Scheduler][startup] startup failed: {}", err)
    end
    return ok
end

--注入线程
function Scheduler:append(name, file)
    wcall(name, 0, FLAG_REQ, "master", "on_append", file)
end

--访问其他线程任务
function Scheduler:broadcast(rpc, ...)
    wbroadcast("", 0, FLAG_REQ, "master", rpc, ...)
end

--访问其他线程任务
function Scheduler:call(name, rpc, ...)
    local session_id = thread_mgr:build_session_id()
    if not wcall(name, session_id, FLAG_REQ, "master", rpc, ... ) then
        return false, "call failed!"
    end
    return thread_mgr:yield(session_id, rpc, RPC_TIMEOUT)
end

--访问其他线程任务
function Scheduler:send(name, rpc, ...)
    wcall(name, 0, FLAG_REQ, "master", rpc, ... )
end

--事件分发
local function notify_rpc(session_id, title, rpc, ...)
    local rpc_datas = event_mgr:notify_listener(rpc, ...)
    if session_id > 0 then
        wcall(title, session_id, FLAG_RES, tunpack(rpc_datas))
    end
end

function quanta.on_scheduler(session_id, flag, ...)
    if flag == FLAG_REQ then
        thread_mgr:fork(notify_rpc, session_id, ...)
        return
    end
    thread_mgr:response(session_id, ...)
end

quanta.scheduler = Scheduler()

return Scheduler
