--lock_test.lua

local log_debug  = logger.debug

local thread_mgr = quanta.get("thread_mgr")

local function test_a(index)
    local _<close> = thread_mgr:lock("sync_lock_test", true)
    thread_mgr:sleep(10)
    log_debug("test_a:{}", index)
end

local function test_b(index)
    local _<close> = thread_mgr:lock("sync_lock_test", true)
    thread_mgr:sleep(10)
    test_a(index)
    log_debug("test_b:{}", index)
end

local function test_c(index)
    local _<close> = thread_mgr:lock("sync_lock_test", true)
    thread_mgr:sleep(10)
    test_b(index)
    log_debug("test_c:{}", index)
end

local function test_loop_lock(index)
    log_debug("lock:{}", index)
    local _<close> = thread_mgr:lock("test_loop", true)
    if 1 == index then
        thread_mgr:sleep(10)
    end
    log_debug("unlock:{}", index)
end

local function test1()
    thread_mgr:fork(function()
        for i = 1, 10 do
            thread_mgr:fork(function()
                test_b(i)
            end)
        end
    end)
end

local function test2()
    thread_mgr:fork(function()
        for i = 1, 10 do
            thread_mgr:fork(function()
                test_c(i)
            end)
        end
        thread_mgr:sleep(1000)
        for i = 1, 10 do
            thread_mgr:fork(function()
                test_c(i)
            end)
        end
        local tbc = {}
        for i = 1, 100 do
            tbc[#tbc + 1] = thread_mgr:fork(function()
                test_loop_lock(i)
            end)
        end
    end)
end

test1()
test2()
