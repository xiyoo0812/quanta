--sync_lock.lua
--[[提供协程同步锁功能
示例:
    local SyncLock = import("kernel/core/sync_lock.lua")
    local lock<defer> = SyncLock(key)
    ...
--]]

local thread_mgr    = quanta.get("thread_mgr")

local SyncLock  = class()
local prop = property(SyncLock)
prop:reader("key", nil)

function SyncLock:__init(key)
    self.key = key
    thread_mgr:lock(key)
end

function SyncLock:__defer()
    thread_mgr:unlock(self.key)
end

return SyncLock
