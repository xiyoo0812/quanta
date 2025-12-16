--update_mgr.lua

local pairs         = pairs
local odate         = os.date
local qtweak        = qtable.weak
local log_info      = logger.info
local log_clean     = logger.clean
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

local Functor       = import("feature/functor.lua")

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
    for obj, functor in pairs(self.second_objs) do
        functor:call(obj, clock_ms)
    end
end

function UpdateMgr:update(now_ms, clock_ms, master)
    --业务更新
    quanta.frame_ms = clock_ms - quanta.clock_ms
    quanta.clock_ms = clock_ms
    quanta.now_ms = now_ms
    --帧更新
    local frame = quanta.frame + 1
    for _, functor in pairs(self.frame_funcs) do
        functor:call(clock_ms, frame)
    end
    for obj, functor in pairs(self.frame_objs) do
        functor:call(obj, clock_ms, frame)
    end
    quanta.frame = frame
    --快帧100ms更新
    if clock_ms < self.next_frame then
        return
    end
    for obj, functor in pairs(self.fast_objs) do
        functor:call(obj, clock_ms)
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
    for obj, functor in pairs(self.second5_objs) do
        functor:call(obj, clock_ms)
    end
    --30秒更新
    if time.sec % 30 > 0 then
        return
    end
    for obj, functor in pairs(self.second30_objs) do
        functor:call(obj, clock_ms)
    end
    --分更新
    if time.min == self.last_minute then
        return
    end
    self.last_minute = time.min
    for obj, functor in pairs(self.minute_objs) do
        functor:call(obj, clock_ms)
    end
    --时更新
    local cur_hour = time.hour
    if cur_hour == self.last_hour then
        return
    end
    self.last_hour = cur_hour
    for obj, functor in pairs(self.hour_objs) do
        functor:call(obj, clock_ms)
    end
    --清理日志
    log_clean();
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
    timer_mgr:once(FAST_MS, function()
        log_info("[UpdateMgr][quit] service real quit !")
        quanta.run = nil
    end)
end

local function define_functions()
    local func_names = {
        "fast", "frame",
        "quit", "hour", "minute", "second", "second5", "second30"
    }
    for idx, name in ipairs(func_names) do
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
            local attach_func = obj[attach_fname]
            if not attach_func then
                log_warn("[UpdateMgr][{}] obj({}) isn't {} method!", attach_name, obj:source(), attach_fname)
                return
            end
            self[attr_oname][obj] = Functor(attach_func, idx > 2)
        end
        UpdateMgr[detach_name] = function(self, obj)
            self[attr_oname][obj] = nil
        end
        UpdateMgr[register_name] = function(self, rname, func, reenter)
            self[attr_rname][rname] = Functor(func, reenter or true)
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
