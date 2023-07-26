--scheduler.lua
local lcodec        = require("lcodec")
local lworker       = require("lworker")

local pcall         = pcall
local log_err       = logger.err
local tmove         = table.move
local tpack         = table.pack
local tinsert       = table.insert
local tunpack       = table.unpack

local lencode       = lcodec.encode_slice
local ldecode       = lcodec.decode_slice

local FLAG_REQ      = quanta.enum("FlagMask", "REQ")
local FLAG_RES      = quanta.enum("FlagMask", "RES")
local RPC_TIMEOUT   = quanta.enum("NetwkTime", "RPC_CALL_TIMEOUT")

local RPC_PERFRAME  = 400

local event_mgr     = quanta.get("event_mgr")
local thread_mgr    = quanta.get("thread_mgr")

local Scheduler = singleton()
local prop = property(Scheduler)
prop:reader("contexts", {})

function Scheduler:__init()
    lworker.setup("quanta", environ.get("QUANTA_SANDBOX"))
end

function Scheduler:quit()
    lworker.shutdown()
end

function Scheduler:update(clock_ms)
    lworker.update(clock_ms)
    local all_datas = self.contexts
    for i, args in pairs(all_datas) do
        local name, session_id = args[1], args[2]
        if not lworker.call(name, lencode(session_id, tunpack(args, 3))) then
            if session_id > 0 then
                thread_mgr:response(session_id, false, "send failed!")
            end
        end
        if i >= RPC_PERFRAME then
            self.contexts = tmove(all_datas, i + 1, #all_datas, 1, {})
            return
        end
    end
    self.contexts = {}
end

function Scheduler:startup(name, entry)
    local ok, err = pcall(lworker.startup, name, entry)
    if not ok then
        log_err("[Scheduler][startup] startup failed: %s", err)
    end
    return ok
end

--访问其他线程任务
function Scheduler:broadcast(rpc, ...)
    lworker.broadcast(lencode(0, FLAG_REQ, "master", rpc, ...))
end

--访问其他线程任务
function Scheduler:call(name, rpc, ...)
    local session_id = thread_mgr:build_session_id()
    tinsert(self.contexts, { name, session_id, FLAG_REQ, "master", rpc, ... })
    return thread_mgr:yield(session_id, rpc, RPC_TIMEOUT)
end

--访问其他线程任务
function Scheduler:send(name, rpc, ...)
    tinsert(self.contexts, { name, 0, FLAG_REQ, "master", rpc, ... })
end

--事件分发
local function notify_rpc(session_id, title, rpc, ...)
    local rpc_datas = event_mgr:notify_listener(rpc, ...)
    if session_id > 0 then
        lworker.call(title, lencode(session_id, FLAG_RES, tunpack(rpc_datas)))
    end
end

--事件分发
local function scheduler_rpc(session_id, flag, ...)
    if flag == FLAG_REQ then
        notify_rpc(session_id, ...)
    else
        thread_mgr:response(session_id, ...)
    end
end

function quanta.on_scheduler(slice)
    local rpc_res = tpack(pcall(ldecode, slice))
    if not rpc_res[1] then
        log_err("[Scheduler][on_scheduler] decode failed %s!", rpc_res[2])
        return
    end
    thread_mgr:fork(function()
        scheduler_rpc(tunpack(rpc_res, 2))
    end)
end

quanta.scheduler = Scheduler()

return Scheduler
