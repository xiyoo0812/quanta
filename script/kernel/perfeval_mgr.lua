--perfeval_mgr.lua
local ltimer = require("ltimer")

local pairs         = pairs
local tpack         = table.pack
local tunpack       = table.unpack
local ltime         = ltimer.time
local env_status    = environ.status
local raw_yield     = coroutine.yield
local raw_resume    = coroutine.resume
local raw_running   = coroutine.running

local EvalSlot      = import("kernel/object/eval_slot.lua")

local PerfevalMgr = singleton()
local prop = property(PerfevalMgr)
prop:reader("eval_id", 0)
prop:reader("perfeval", false)  --性能开关
prop:reader("eval_co_map", {})  --协程评估表
function PerfevalMgr:__init()
end

function PerfevalMgr:setup()
    -- 初始化开关
    self.perfeval = env_status("QUANTA_PERFEVAL")
    --协程改造
    coroutine.yield = function(...)
        self:yield()
        return raw_yield(...)
    end
    coroutine.resume = function(co, ...)
        self:yield()
        self:resume(co)
        local args = tpack(raw_resume(co, ...))
        self:resume()
        return tunpack(args)
    end
end

function PerfevalMgr:yield()
    if self.perfeval then
        local now_ms = ltime()
        local yield_co = raw_running()
        local eval_cos = self.eval_co_map[yield_co]
        for _, eval_data in pairs(eval_cos or {}) do
            eval_data.yield_tick = now_ms
        end
    end
end

function PerfevalMgr:resume(co)
    if self.perfeval then
        local now_ms = ltime()
        local resume_co = co or raw_running()
        local eval_cos = self.eval_co_map[resume_co]
        for _, eval_data in pairs(eval_cos or {}) do
            if eval_data.yield_tick > 0 then
                local pause_time = now_ms - eval_data.yield_tick
                eval_data.yield_time = eval_data.yield_time + pause_time
                eval_data.yield_tick = 0
            end
        end
    end
end

function PerfevalMgr:get_eval_id()
    self.eval_id = self.eval_id + 1
    if self.eval_id >= 0x7fffffff then
        self.eval_id = 1
    end
    return self.eval_id
end

function PerfevalMgr:eval(eval_name)
    if self.perfeval then
        return EvalSlot(self, eval_name)
    end
end

function PerfevalMgr:start(eval_name)
    local co = raw_running()
    local eval_id = self:get_eval_id()
    local eval_data = {
        co = co,
        yield_time = 0,
        eval_id = eval_id,
        eval_name = eval_name,
        begin_time = ltime(),
    }
    local eval_cos = self.eval_co_map[co]
    if eval_cos then
        eval_cos[eval_id] = eval_data
    else
        self.eval_co_map[co] = { [eval_id] = eval_data }
    end
    return eval_data
end

function PerfevalMgr:stop(eval_data)
    local now_ms = ltime()
    local eval_name = eval_data.eval_name
    local eval_time = now_ms - eval_data.begin_time - eval_data.yield_time
    
    self.eval_co_map[eval_data.co][eval_data.eval_id] = nil
end

quanta.perfeval_mgr = PerfevalMgr()

return PerfevalMgr
