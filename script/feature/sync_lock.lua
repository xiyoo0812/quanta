--sync_lock.lua
--[[提供协程同步锁功能
示例:
    local lock<close> = thread_mgr:lock(key)
    ...
--]]
local co_running    = coroutine.running

local thread_mgr    = quanta.get("thread_mgr")

local SECOND_10_MS  = quanta.enum("PeriodTime", "SECOND_10_MS")

local SyncLock = class()
local prop = property(SyncLock)
prop:reader("timeout", 0)
prop:reader("count", 1)
prop:reader("key", nil)
prop:reader("co", nil)

function SyncLock:__init(key)
    self.timeout = quanta.clock_ms + SECOND_10_MS
    self.co = co_running()
    self.key = key
end

function SyncLock:lock()
    self.count = self.count + 1
end

function SyncLock:unlock()
    if self.count > 0 then
        self.count = self.count - 1
        if self.count == 0 then
            thread_mgr:unlock(self.key)
        end
    end
end

function SyncLock:is_timeout(clock_ms)
    return self.timeout <= clock_ms
end

function SyncLock:__defer()
    self:unlock()
end

return SyncLock
