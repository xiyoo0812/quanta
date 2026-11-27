-- lock_test.lua
local log_info      = logger.info

local thread_mgr    = quanta.get("thread_mgr")

local LOCK_KEY      = "feature_lock_test"

local TestCase      = import("test/case.lua")
local LockTest      = class(TestCase)

function LockTest:run()
    local active = 0          --当前在临界区内的协程数
    local max_active = 0      --临界区内最大并发数(互斥时应恒为 1)
    local entered = 0         --成功进入临界区的次数
    local task_count = 20

    local function critical_section(index)
        local _<close> = thread_mgr:lock(LOCK_KEY, true)
        --进入临界区
        active = active + 1
        if active > max_active then max_active = active end
        entered = entered + 1
        thread_mgr:sleep(5)
        --离开临界区(lock 的 <close> 会自动 unlock)
        active = active - 1
    end

    --启动多个协程竞争同一把锁
    for i = 1, task_count do
        thread_mgr:fork(function()
            critical_section(i)
        end)
    end

    --等待所有协程完成(每个 5ms 且串行, 20 个约需 100ms+; 留足余量)
    --分多段等待, 让调度器充分 drain 锁队列
    for _ = 1, 5 do
        thread_mgr:sleep(200)
    end

    self:report("all tasks entered", entered == task_count, entered, task_count)
    self:report("mutex max_active==1", max_active == 1, max_active, 1)
    self:report("active back to zero", active == 0, active, 0)
    log_info("[lock] {} tasks, max_active={}", task_count, max_active)
end

return LockTest
