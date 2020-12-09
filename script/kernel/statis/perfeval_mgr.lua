--perfeval_mgr.lua
local pairs         = pairs
local mhuge         = math.huge
local mmax          = math.max
local mmin          = math.min
local tpack         = table.pack
local tunpack       = table.unpack
local log_info      = logger.info
local env_status    = environ.status
local raw_yield     = coroutine.yield
local raw_resume    = coroutine.resume
local raw_running   = coroutine.running
local get_time_ms   = quanta.get_time_ms

--性能统计打印时间
local PeriodTime    = enum("PeriodTime")

local PerfevalMgr = singleton()
function PerfevalMgr:__init()
    -- 性能开关
    self.perfeval = false
    -- 数据
    self.perfeval_map = {}
    -- 协程评估表
    self.eval_co_map = {}
    self.eval_id = 0
end

function PerfevalMgr:setup()
    -- 加入dump
    quanta.join_dump(self)
    -- 初始化开关
    self:set_perfeval(env_status("QUANTA_PERFEVAL"))
end

function PerfevalMgr:set_perfeval(status)
    local timer_mgr     = quanta.timer_mgr
    if self.timer_id then
        timer_mgr:unregister(self.timer_id)
    end
    self.perfeval = status
    if status then
        self.timer_id = timer_mgr:loop(PeriodTime.MINUTE_10_MS, function()
           self:dump()
        end)
    end
end

function PerfevalMgr:yield()
    if self.perfeval then
        local now_ms = get_time_ms()
        local yield_co = raw_running()
        local eval_cos = self.eval_co_map[yield_co]
        for _, eval_data in pairs(eval_cos or {}) do
            eval_data.yield_tick = now_ms
        end
    end
end

function PerfevalMgr:resume(co)
    if self.perfeval then
        local now_ms = get_time_ms()
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

function PerfevalMgr:begin_eval(eval_name)
    if self.perfeval then
        local co = raw_running()
        local eval_id = self:get_eval_id()
        local eval_data = {
            co = co,
            yield_time = 0,
            eval_id = eval_id,
            eval_name = eval_name,
            begin_time = get_time_ms(),
        }
        local eval_cos = self.eval_co_map[co]
        if eval_cos then
            eval_cos[eval_id] = eval_data
        else
            self.eval_co_map[co] = { [eval_id] = eval_data }
        end
        return eval_data
    end
end

function PerfevalMgr:end_eval(eval_data)
    if self.perfeval and eval_data then
        local now_ms = get_time_ms()
        local eval_name = eval_data.eval_name
        local pref_eval = self.perfeval_map[eval_name]
        if not pref_eval then
            pref_eval = {
                count = 0,
                max_time = 0,
                min_time = mhuge,
                total_time = 0,
                recent_count = 0,
                recent_total_time = 0,
            }
            self.perfeval_map[eval_name] = pref_eval
        end
        local eval_time = now_ms - eval_data.begin_time - eval_data.yield_time
        pref_eval.count = pref_eval.count + 1
        pref_eval.recent_count = pref_eval.recent_count + 1
        pref_eval.total_time = pref_eval.total_time + eval_time
        pref_eval.recent_total_time = pref_eval.recent_total_time + eval_time
        pref_eval.max_time = mmax(eval_time, pref_eval.max_time)
        pref_eval.min_time = mmin(eval_time, pref_eval.min_time)
        self.eval_co_map[eval_data.co][eval_data.eval_id] = nil
    end
end

function PerfevalMgr:dump_call(eval_name)
    if self.perfeval then
        local pref_eval = self.perfeval_map[eval_name]
        if pref_eval then
            log_info("quanta dump call performance evaluation %s:", eval_name)
            log_info("----------------------------------------------------")
            self:dump_eval_item(eval_name, pref_eval)
        end
    end
end

function PerfevalMgr:dump_eval_item(eval_name, pref_eval)
    local avg_time = pref_eval.count > 0 and pref_eval.total_time / pref_eval.count or 0
    local recent_avg_time = pref_eval.recent_count > 0 and pref_eval.recent_total_time / pref_eval.recent_count or 0
    log_info("<%s => count=%s max_time=%.3f min_time=%.3f avg_time=%.3f recent_count=%s, recent_avg_time=%.3f/>",
        eval_name, pref_eval.count, pref_eval.max_time, pref_eval.min_time, avg_time, pref_eval.recent_count, recent_avg_time)
end

function PerfevalMgr:dump()
    log_info("quanta dump all call performance evaluation:")
    log_info("----------------------------------------------------")
    for eval_name, pref_eval in pairs(self.perfeval_map) do
        self:dump_eval_item(eval_name, pref_eval)
        --清除最近状态
        pref_eval.recent_total_time = 0
        pref_eval.recent_count = 0
    end
    log_info("----------------------------------------------------")
end

local perfeval_mgr = PerfevalMgr()

--协程改造
coroutine.yield = function(...)
    perfeval_mgr:yield()
    return raw_yield(...)
end

coroutine.resume = function(co, ...)
    perfeval_mgr:yield()
    perfeval_mgr:resume(co)
    local args = tpack(raw_resume(co, ...))
    perfeval_mgr:resume()
    return tunpack(args)
end

quanta.perfeval_mgr = perfeval_mgr

return PerfevalMgr
