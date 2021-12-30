--luapanda.lua
--集成腾讯LuaPanda调试工具
local env_status    = environ.status
local raw_create    = coroutine.create

local thread_mgr    = quanta.get("thread_mgr")

--网络时间常量定义
local HookState = enum("HookState", 0)
HookState.DISCONNECT_HOOK   = 0,    --断开连接
HookState.LITE_HOOK         = 1,    --全局无断点
HookState.MID_HOOK          = 2,    --全局有断点，本文件无断点
HookState.ALL_HOOK          = 3,    --本文件有断点

local RunState = enum("RunState", 0)
RunState.WAIT_CMD           = 1,    --已连接，等待命令
RunState.STOP_ON_ENTRY      = 2,    --初始状态
RunState.RUN                = 3,
RunState.STEPOVER           = 4,
RunState.STEPIN             = 5,
RunState.STEPOUT            = 6,
RunState.STEPOVER_STOP      = 7,
RunState.STEPIN_STOP        = 8,
RunState.STEPOUT_STOP       = 9,
RunState.HIT_BREAKPOINT     = 10

local LuaPanda = singleton()
local prop = property(LuaPanda)
prop:reader("enable", false)        --是否启用
prop:reader("listener", nil)        --网络连接对象
prop:reader("run_statue", RunState.WAIT_CMD)
prop:reader("hook_statue", HookState.DISCONNECT_HOOK)
function LuaPanda:__init()
end

--启动
function LuaPanda:start()
    if not self.listener then
        local socket = Socket(self)
        local host_ip = env_status("QUANTA_HOST_IP")
        if not socket:listen(host_ip, 8812) then
            log_info("[LuaPanda][start] now listen %s failed", http_addr)
            return
        end
        self.listener = socket
        log_info("[LuaPanda][start] listen %s success!", http_addr)
    end
    self.enable = true
    --协程HOOK
    local coroutine_pool = thread_mgr:get_coroutine_pool()
    for _, co in coroutine_pool:iter() do
        self:change_hook_state(co)
    end
    --协程改造
    coroutine.create = function(...)
        local co =  raw_create(...)
        self:change_hook_state(co)
        return co
    end
end

--停止
function LuaPanda:stop()
    self.enable = false
    local coroutine_pool = thread_mgr:get_coroutine_pool()
    for _, co in coroutine_pool:iter() do
        self:change_hook_state(co)
    end
    --协程改造
    coroutine.create = raw_create
end

function LuaPanda:change_hook_state(co)
    local state = self.hook_state
    if state == HookState.DISCONNECT_HOOK then
        if self.enable == true then
            debug.sethook(co, LuaPanda.debug_hook, "r", 1000000);
        else
            debug.sethook(co, LuaPanda.debug_hook, "");
        end
    elseif state == HookState.LITE_HOOK then
        debug.sethook(co , LuaPanda.debug_hook, "r");
    elseif state == HookState.MID_HOOK then
        debug.sethook(co , LuaPanda.debug_hook, "rc");
    elseif state == HookState.ALL_HOOK then
        debug.sethook(co , LuaPanda.debug_hook, "lrc");
    end
end

quanta.luapanda = LuaPanda()

return LuaPanda
