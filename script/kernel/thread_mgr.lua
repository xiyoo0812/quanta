--thread_mgr.lua
local tsort         = table.sort
local tsize         = table.size
local tpack         = table.pack
local tunpack       = table.unpack
local tclean        = table.clean
local sformat       = string.format
local co_yield      = coroutine.yield
local co_create     = coroutine.create
local co_resume     = coroutine.resume
local co_running    = coroutine.running
local co_status     = coroutine.status
local qxpcall       = quanta.xpcall
local synclock      = quanta.synclock
local qbindtrace    = quanta.bind_trace
local log_warn      = logger.warn
local log_err       = logger.err

local Queue         = import("container/queue.lua")

local SECOND_30_MS  = quanta.enum("PeriodTime", "SECOND_30_MS")

local ThreadMgr = singleton()
local prop = property(ThreadMgr)
prop:reader("syncqueue_map", {})
prop:reader("coroutine_yields", {})
prop:reader("coroutine_waitings", {})
prop:reader("coroutine_pool", nil)
prop:reader("wakeups", {})
prop:reader("lock_co", nil)
prop:reader("frame_wakeups", 0)

function ThreadMgr:__init()
    self.coroutine_pool = Queue(1024)
    self.lock_co = co_create(function()
        while true do
            if #self.wakeups > 0 then
                self:drain_wakeups()
            else
                co_yield()
            end
        end
    end)
end

function ThreadMgr:idle_size()
    return self.coroutine_pool:size()
end

function ThreadMgr:wait_size()
    local co_yield_size = tsize(self.coroutine_yields)
    local co_wait_size = tsize(self.coroutine_waitings)
    return co_yield_size + co_wait_size + #self.wakeups + 1
end

function ThreadMgr:lock(key, waiting)
    local queue = self.syncqueue_map[key]
    if not queue then
        queue = Queue()
        self.syncqueue_map[key] = queue
    end
    queue.ttl = quanta.clock_ms + SECOND_30_MS
    local head = queue:head()
    if not head then
        local lock = synclock(key)
        queue:push(lock)
        return lock
    end
    if head.co == co_running() then
        --防止重入
        head:lock()
        return head
    end
    if waiting then
        --等待则挂起
        local lock = synclock(key)
        queue:push(lock)
        co_yield()
        return lock
    end
end

function ThreadMgr:unlock(key, co)
    local queue = self.syncqueue_map[key]
    if queue then
        local head = queue:head()
        if head and head.co == co then
            queue:pop()
            local nxt = queue:head()
            if nxt then
                self:wakeup("lock", nxt.co)
            end
        end
    end
end

function ThreadMgr:wakeup(tag, co, ...)
    local wakeups = self.wakeups
    wakeups[#wakeups + 1] = { co = co, tag = tag, args = tpack(...) }
end

function ThreadMgr:drain_pending()
    self.frame_wakeups = 0
    if #self.wakeups == 0 then
        return
    end
    local status = co_status(self.lock_co)
    if status ~= "suspended" then
        log_err("[ThreadMgr][drain_pending] lock_co status({}) invalid!", status)
        return
    end
    local ok, err = co_resume(self.lock_co)
    if not ok then
        log_err("[ThreadMgr][drain_pending] lock_co resume failed: {}", err)
    end
    return ok, err
end

function ThreadMgr:drain_wakeups()
    local i = 1
    local wakeups = self.wakeups
    while i <= #wakeups do
        local item = wakeups[i]
        i = i + 1
        local args = item.args
        local ok, err = co_resume(item.co, tunpack(args, 1, args.n))
        if not ok then
            log_err("[ThreadMgr][drain_wakeups] resume failed: tag={} co={} err={}", item.tag, tostring(item.co), err)
        end
    end
    tclean(wakeups)
end

function ThreadMgr:try_response(session_id, ...)
    local context = self.coroutine_yields[session_id]
    if not context then
        return false
    end
    self.coroutine_yields[session_id] = nil
    self:wakeup(session_id, context.co, ...)
    return true
end

function ThreadMgr:response(session_id, ...)
    if not self:try_response(session_id, ...) then
        log_warn("[ThreadMgr][response] unknown session_id({}) response!", session_id)
    end
end

function ThreadMgr:resume(co, ...)
    return self:wakeup("resume", co, ...)
end

function ThreadMgr:yield(session_id, title, ms_to, ...)
    local context = {co = co_running(), title = title, to = quanta.clock_ms + ms_to}
    self.coroutine_yields[session_id] = context
    return co_yield(...)
end

function ThreadMgr:on_second30(clock_ms)
    for key, queue in pairs(self.syncqueue_map) do
        if queue:empty() and clock_ms > queue.ttl then
            self.syncqueue_map[key] = nil
        end
    end
end

function ThreadMgr:on_fast(clock_ms)
    --检查协程超时
    local timeout_coroutines = {}
    for co, ms_to in pairs(self.coroutine_waitings) do
        if ms_to <= clock_ms then
            timeout_coroutines[#timeout_coroutines + 1] = co
        end
    end
    --处理协程超时
    if next(timeout_coroutines) then
        for _, co in pairs(timeout_coroutines) do
            self.coroutine_waitings[co] = nil
            self:wakeup("sleep", co)
        end
    end
end

function ThreadMgr:on_second(clock_ms)
    --处理锁超时
    for key, queue in pairs(self.syncqueue_map) do
        local head = queue:head()
        if head and head:is_timeout(clock_ms) then
            self:unlock(key, head.co)
        end
    end
    --检查协程超时
    local timeout_coroutines = {}
    for session_id, context in pairs(self.coroutine_yields) do
        if context.to <= clock_ms then
            context.session_id = session_id
            timeout_coroutines[#timeout_coroutines + 1] = context
        end
    end
    --处理协程超时
    if next(timeout_coroutines) then
        tsort(timeout_coroutines, function(a, b) return a.to < b.to end)
        for _, context in ipairs(timeout_coroutines) do
            local session_id = context.session_id
            if self:try_response(session_id, false, sformat("%s timeout", context.title), session_id) then
                if context.title then
                    log_err("[ThreadMgr][on_second] session_id({}:{}) timeout!", session_id, context.title)
                end
            end
        end
    end
end

function ThreadMgr:fork(f, chain, ...)
    local pool = self.coroutine_pool
    local co = pool:pop()
    if co == nil then
        co = co_create(function()
            while true do
                local func, cchain = co_yield()
                qbindtrace(cchain, co)
                qxpcall(func, "[ThreadMgr][fork] fork run error: {}", co_yield())
                if cchain then
                    cchain:output()
                end
                pool:push(co)
            end
        end)
        co_resume(co)
    end
    co_resume(co, f, chain)
    co_resume(co, ...)
end

function ThreadMgr:sleep(ms)
    local co = co_running()
    self.coroutine_waitings[co] = quanta.clock_ms + ms
    co_yield()
end

function ThreadMgr:success_call(period, success_func, interval, try_time)
    self:fork(function()
        if interval then
            self:sleep(interval)
        end
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
