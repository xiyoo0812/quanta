--thread_mgr.lua
local select        = select
local log_err       = logger.err
local tremove       = table.remove
local tunpack       = table.unpack
local tinsert       = table.insert
local sformat       = string.format
local co_yield      = coroutine.yield
local co_create     = coroutine.create
local co_resume     = coroutine.resume
local co_running    = coroutine.running     -- 获取当前运行协程
local tcopy         = table_ext.copy
local qxpcall       = quanta.xpcall

local ThreadMgr = singleton()
local prop = property(ThreadMgr)
prop:reader("session_id", 1)
prop:reader("coroutine_pool", {})
prop:reader("session_id_coroutine", {})

function ThreadMgr:__init()
end

function ThreadMgr:size()
    local co_cur_max = #self.coroutine_pool
    local co_cur_size = #self.session_id_coroutine + 1
    return co_cur_size, co_cur_max
end

function ThreadMgr:co_create(f)
    local co = tremove(self.coroutine_pool)
    if co == nil then
        co = co_create(function(...)
            qxpcall(f, "fork error: %s", ...)
            while true do
                f = nil
                tinsert(self.coroutine_pool, co)
                f = co_yield()
                qxpcall(f, "fork error: %s", co_yield())
            end
        end)
    else
        co_resume(co, f)
    end
    return co
end

function ThreadMgr:response(session_id, ...)
    local context = self.session_id_coroutine[session_id]
    if not context then
        log_err("[ThreadMgr][response]unknown session_id(%s) response!", session_id)
        self.session_id_coroutine[session_id] = nil
        return
    end
    self.session_id_coroutine[session_id] = nil
    self:resume(context.co, ...)
end

function ThreadMgr:resume(co, ...)
    return co_resume(co, ...)
end

function ThreadMgr:yield(session_id, title, ms_to, ...)
    local context = {co = co_running(), title = title, to = quanta.now_ms + ms_to}
    self.session_id_coroutine[session_id] = context
    return co_yield(...)
end

function ThreadMgr:update(now_ms)
    local session_id_coroutine = tcopy(self.session_id_coroutine)
    for session_id, context in pairs(session_id_coroutine) do
        if context.to <= now_ms then
            if context.title then
                log_err("[ThreadMgr][update] session_id(%s:%s) timeout!", session_id, context.title)
            end
            self.session_id_coroutine[session_id] = nil
            self:resume(context.co, false, sformat("%s timeout", context.title), session_id)
        end
    end
end

function ThreadMgr:fork(f, ...)
    local n = select("#", ...)
    local co
    if n == 0 then
        co = self:co_create(f)
    else
        local args = { ... }
        co = self:co_create(function() f(tunpack(args, 1, n)) end)
    end
    self:resume(co, ...)
    return co
end

function ThreadMgr:sleep(ms)
    local session_id = self:build_session_id()
    self:yield(session_id, nil, ms)
end

function ThreadMgr:build_session_id()
    self.session_id = self.session_id + 1
    if self.session_id >= 0x7fffffff then
        self.session_id = 1
    end
    return self.session_id
end

function ThreadMgr:success_call(period, success_func, try_time)
    self:fork(function()
        try_time = try_time or 10
        while true do
            if success_func() or try_time <= 0 then
                break
            end
            try_time = try_time - 1
            self:sleep(period)
        end
    end)
end

quanta.thread_mgr = ThreadMgr()

return ThreadMgr
