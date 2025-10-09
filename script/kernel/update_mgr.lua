--update_mgr.lua

local pairs         = pairs
local odate         = os.date
local qtweak        = qtable.weak
local log_info      = logger.info
local sformat       = string.format
local log_warn      = logger.warn
local sig_get       = signal.get
local sig_check     = signal.check
local sig_reload    = signal.reload
local collectgarbage= collectgarbage

local event_mgr     = quanta.get("event_mgr")
local timer_mgr     = quanta.get("timer_mgr")
local thread_mgr    = quanta.get("thread_mgr")

local HOTFIXABLE    = environ.status("QUANTA_HOTFIX")

local FAST_MS       = quanta.enum("PeriodTime", "FAST_MS")
local HALF_MS       = quanta.enum("PeriodTime", "HALF_MS")

local UpdateMgr = singleton()
local prop = property(UpdateMgr)
prop:reader("last_hour", 0)
prop:reader("next_frame", 0)
prop:reader("last_minute", 0)

function UpdateMgr:__init()
        --设置弱表
    self:weak_handlers()
    --注册订阅
    self:attach_fast(thread_mgr)
    self:attach_frame(event_mgr)
    self:attach_frame(timer_mgr)
    self:attach_second(event_mgr)
    self:attach_second(thread_mgr)
    self:attach_second30(thread_mgr)
    --初始化变量
    local time = odate("*t")
    self.last_minute = time.min
    self.last_hour = time.hour
end

function UpdateMgr:update_second(clock_ms)
    for obj, address in pairs(self.second_objs) do
        thread_mgr:entry(address, function()
            obj:on_second(clock_ms)
        end)
    end
end

function UpdateMgr:update(now_ms, clock_ms, master)
    --业务更新
    quanta.frame_ms = clock_ms - quanta.clock_ms
    quanta.clock_ms = clock_ms
    quanta.now_ms = now_ms
    --帧更新
    local frame = quanta.frame + 1
    for _, func in pairs(self.frame_funcs) do
        func(clock_ms, frame)
    end
    for obj, address in pairs(self.frame_objs) do
        thread_mgr:entry(address, function()
            obj:on_frame(clock_ms, frame)
        end)
    end
    quanta.frame = frame
    --快帧100ms更新
    if clock_ms < self.next_frame then
        return
    end
    for obj, address in pairs(self.fast_objs) do
        thread_mgr:entry(address, function()
            obj:on_fast(clock_ms)
        end)
    end
    self.next_frame = clock_ms + FAST_MS
    --秒更新
    local now = now_ms // 1000
    if now == quanta.now then
        return
    end
    quanta.now = now
    --热更检查
    if HOTFIXABLE then
        quanta.reload()
    end
    --执行gc
    collectgarbage("step", 10)
    --信号检查
    if master then
        self:check_signal()
    end
    --时间更新
    self:update_second(clock_ms)
    self:update_by_time(now, clock_ms)
end

function UpdateMgr:update_by_time(now, clock_ms)
    --5秒更新
    local time = odate("*t", now)
    if time.sec % 5 > 0 then
        return
    end
    for obj in pairs(self.second5_objs) do
        thread_mgr:fork(function()
            obj:on_second5(clock_ms)
        end)
    end
    --30秒更新
    if time.sec % 30 > 0 then
        return
    end
    for obj in pairs(self.second30_objs) do
        thread_mgr:fork(function()
            obj:on_second30(clock_ms)
        end)
    end
    --分更新
    if time.min == self.last_minute then
        return
    end
    self.last_minute = time.min
    for obj in pairs(self.minute_objs) do
        thread_mgr:fork(function()
            obj:on_minute(clock_ms)
        end)
    end
    --时更新
    local cur_hour = time.hour
    if cur_hour == self.last_hour then
        return
    end
    self.last_hour = cur_hour
    for obj in pairs(self.hour_objs) do
        thread_mgr:fork(function()
            obj:on_hour(clock_ms, cur_hour, time)
        end)
    end
    --每日4点执行一次全量更新
    if cur_hour == 4 then
        collectgarbage("collect")
    end
    log_info("[UpdateMgr][update]now lua mem: {}!", collectgarbage("count"))
end

function UpdateMgr:check_signal()
    local signal = sig_get()
    if sig_reload(signal) then
        log_info("[UpdateMgr][check_signal]service reload for signal !")
        --重新加载脚本
        quanta.reload()
        --事件通知
        event_mgr:notify_trigger("on_reload")
        --输出状态
        quanta.report("reload")
    end
    if sig_check(signal) then
        log_info("[UpdateMgr][check_signal]service quit for signal !")
        self:quit()
    end
end

function UpdateMgr:quit()
    log_info("[UpdateMgr][quit] service quit !")
    for obj in pairs(self.quit_objs) do
        obj:on_quit()
    end
    --退出
    timer_mgr:once(HALF_MS, function()
        log_info("[UpdateMgr][quit] service real quit !")
        quanta.run = nil
    end)
end

local function define_functions()
    local func_names = {
        "fast", "quit", "frame",
        "hour", "minute", "second", "second5", "second30"
    }
    for _, name in pairs(func_names) do
        local attr_oname = sformat("%s_objs", name)
        local attr_rname = sformat("%s_funcs", name)
        local attach_fname = sformat("on_%s", name)
        local attach_name = sformat("attach_%s", name)
        local detach_name = sformat("detach_%s", name)
        local register_name = sformat("register_%s", name)
        local unregister_name = sformat("unregister_%s", name)
        --定义属性
        prop:reader(attr_oname, {})
        prop:reader(attr_rname, {})
        --定义函数
        UpdateMgr[attach_name] = function(self, obj)
            if not obj[attach_fname] then
                log_warn("[UpdateMgr][{}] obj({}) isn't {} method!", attach_name, obj:source(), attach_fname)
                return
            end
            self[attr_oname][obj] = obj:address()
        end
        UpdateMgr[detach_name] = function(self, obj)
            self[attr_oname][obj] = nil
        end
        UpdateMgr[register_name] = function(self, rname, func)
            self[attr_rname][rname] = func
        end
        UpdateMgr[unregister_name] = function(self, rname)
            self[attr_rname][rname] = nil
        end
    end
    UpdateMgr.weak_handlers = function(self)
        for _, name in pairs(func_names) do
            local attr_oname = sformat("%s_objs", name)
            qtweak(self[attr_oname])
        end
    end
end

define_functions()

quanta.update_mgr = UpdateMgr()

return UpdateMgr
