--luapanda.lua
--集成腾讯LuaPanda调试工具
local ljson         = require("lcjson")

local log_err       = logger.err
local log_info      = logger.info
local sformat       = string.format
local json_encode   = ljson.encode
local dsethook      = debug.sethook
local dgetinfo      = debug.getinfo
local env_status    = environ.status
local raw_create    = coroutine.create

local thread_mgr    = quanta.get("thread_mgr")

--网络时间常量定义
local HookStatus = enum("HookStatus", 0)
HookStatus.DISCONNECT_HOOK  = 0,    --断开连接
HookStatus.LITE_HOOK        = 1,    --全局无断点
HookStatus.MID_HOOK         = 2,    --全局有断点，本文件无断点
HookStatus.ALL_HOOK         = 3,    --本文件有断点

local RunStatus = enum("RunStatus", 0)
RunStatus.DISCONNECT        = 0,    --未连接
RunStatus.WAIT_CMD          = 1,    --已连接，等待命令
RunStatus.STOP_ON_ENTRY     = 2,    --初始状态
RunStatus.RUN               = 3,
RunStatus.STEPOVER          = 4,
RunStatus.STEPIN            = 5,
RunStatus.STEPOUT           = 6,
RunStatus.STEPOVER_STOP     = 7,
RunStatus.STEPIN_STOP       = 8,
RunStatus.STEPOUT_STOP      = 9,
RunStatus.HIT_BREAKPOINT    = 10

local LuaPanda = singleton()
local prop = property(LuaPanda)
prop:reader("enable", false)        --是否启用
prop:reader("last_tick", 0)         --
prop:reader("socket", nil)          --网络连接对象
prop:reader("listener", nil)        --网络连接对象
prop:reader("call_stacks", {})      --获取当前调用堆栈信息
prop:reader("var_ref_idx", 1)    --变量索引
prop:reader("var_ref_tab", {})   --变量记录table


prop:reader("run_status", RunStatus.DISCONNECT)
prop:reader("hook_status", HookStatus.DISCONNECT_HOOK)
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
    self:change_cos_hook_status()
    --协程改造
    coroutine.create = function(...)
        local co =  raw_create(...)
        self:change_co_hook_status(co)
        return co
    end
end

--停止
function LuaPanda:stop()
    self.enable = false
    self:change_hook_status(HookStatus.DISCONNECT_HOOK)
    --协程改造
    coroutine.create = raw_create
end

function LuaPanda:on_socket_error(socket, token, err)
    if socket == self.listener then
        log_info("[LuaPanda][on_socket_error] listener(%s:%s) close!", self.ip, self.port)
        self.listener = nil
        return
    end
    if socket == self.socket then
        log_debug("[LuaPanda][on_socket_error] client(token:%s) close!", token)
        self.socket = nil
        self:change_hook_status(HookStatus.DISCONNECT_HOOK)
    end
end

function LuaPanda:on_socket_accept(socket, token)
    if self.socket then
        socket:close()
        return
    end
    self.socket = socket
    log_debug("[LuaPanda][on_socket_accept] client(token:%s) connected!", token)
    self:change_run_status(RunStatus.WAIT_CMD)
    if not self:debugger_wait_msg() then
        self:output2vscode("[debugger error]初始化未完成, 建立连接但接收初始化消息失败。请更换端口重试", "debug_console")
        self:detach()
        return
    end
    self:change_hook_status(HookStatus.ALL_HOOK)
    self:output2vscode("debugger init success", "tip")
end

--输出到vscode
function LuaPanda:output2vscode(str, cmd)
    local message = {
        callbackId = 0,
        cmd = cmd or "output",
        info = { logInfo = str }
    }
    self:send_msg(message)
end

-- 向adapter发消息
function LuaPanda:send_msg(message)
    if self.run_status == RunStatus.DISCONNECT then
        self:detach()
        return
    end
    self.socket:send(sformat("%s|*|\n", json_encode(message)))
end

function LuaPanda:on_socket_recv(socket, token)

end

-- 运行状态机，状态变更
function LuaPanda:change_run_status(status)
    self.run_status = status
    --状态切换时，清除记录栈信息的状态
    self.var_ref_idx = 1
    self.call_stacks = {}
    self.var_ref_tab = {}
end

function LuaPanda:change_hook_status(status)
    if self.hook_status == status then
        return
    end
    self.hook_status = status
    self:change_cos_hook_status()
    if status == HookStatus.DISCONNECT_HOOK then
        if self.enable == true then
            dsethook(uaPanda.debug_hook, "r", 1000000)
        else
            dsethook(uaPanda.debug_hook, "")
        end
    elseif status == HookStatus.LITE_HOOK then
        dsethook(LuaPanda.debug_hook, "r")
    elseif status == HookStatus.MID_HOOK then
        dsethook(LuaPanda.debug_hook, "rc")
    elseif status == HookStatus.ALL_HOOK then
        dsethook(LuaPanda.debug_hook, "lrc")
    end
end

function LuaPanda:change_cos_hook_status()
    local coroutine_pool = thread_mgr:get_coroutine_pool()
    for _, co in coroutine_pool:iter() do
        self:change_co_hook_status(co)
    end
end

function LuaPanda:change_co_hook_status(co)
    local status = self.hook_status
    if status == HookStatus.DISCONNECT_HOOK then
        if self.enable == true then
            dsethook(co, LuaPanda.debug_hook, "r", 1000000)
        else
            dsethook(co, LuaPanda.debug_hook, "")
        end
    elseif status == HookStatus.LITE_HOOK then
        dsethook(co , LuaPanda.debug_hook, "r")
    elseif status == HookStatus.MID_HOOK then
        dsethook(co , LuaPanda.debug_hook, "rc")
    elseif status == HookStatus.ALL_HOOK then
        dsethook(co , LuaPanda.debug_hook, "lrc")
    end
end

--HOOK模块
-------------------------------------------------
-- 钩子函数
function LuaPanda:debug_hook(event, line)
    if not self.socket then
        return
    end
    --litehook 仅非阻塞接收断点
    if self.hook_status == HookStatus.LITE_HOOK then
        local ti = quanta.now
        if ti - self.last_tick > 1 then
            self:debugger_wait_msg(0)
            self.last_tick = ti
        end
        return
    end
    --运行中
    local co, is_main = coroutine.running()
    local info = is_main and dgetinfo(2, "Slf") or dgetinfo(co, 2, "Slf")
    self:real_hook_process(event, info)
end

function LuaPanda:real_hook_process(event, info)
    --如果当前行在Debugger中，不做处理
    local matchRes = ((info.source == DebuggerFileName) or (info.source == DebuggerToolsName))
    if matchRes == true then
        return
    end
    --即使MID hook在C中, 或者是Run或者单步时也接收消息
    local rstatus = self.run_status
    if rstatus == RunStatus.RUN or rstatus == RunStatus.STEPOVER or rstatus == RunStatus.STEPIN or rstatus == RunStatus.STEPOUT then
        local ti = quanta.now
        if ti - self.last_tick > 1 then
            self:debugger_wait_msg(0)
            self.last_tick = ti
        end
    end
    --不处理C函数
    if info.source == "=[C]" then
        return
    end
    --使用 info.orininal_source 记录lua虚拟机传来的原始路径
    info.orininal_source = info.source
    --标准路径处理
    info.source = self:getPath(info)
    --本次执行的函数和上次执行的函数作对比，防止在一行停留两次
    if lastRunFunction["currentline"] == info["currentline"] and lastRunFunction["source"] == info["source"] and lastRunFunction["func"] == info["func"] and lastRunFunction["event"] == event then
        self:printToVSCode("run twice")
    end
    --记录最后一次调用信息
    lastRunFunction = info
    lastRunFunction["event"] = event
    lastRunFilePath = info.source
    --输出函数信息到前台
    if logLevel == 0 then
        local logTable = {"[lua hook] event:", tostring(event), " self.run_status:",tostring(self.run_status)," currentHookState:",tostring(currentHookState)," jumpFlag:", tostring(jumpFlag)}
        for k,v in pairs(info) do
            table.insert(logTable, tostring(k))
            table.insert(logTable, ":")
            table.insert(logTable, tostring(v))
            table.insert(logTable, " ")
        end
        local logString = table.concat(logTable)
        self:printToVSCode(logString)
    end

    --仅在line时做断点判断。进了断点之后不再进入本次STEP类型的判断，用Aflag做标记
    local isHit = false
    if event == "line" then
        if rstatus == RunStatus.RUN or rstatus == RunStatus.STEPOVER or rstatus == RunStatus.STEPIN or rstatus == RunStatus.STEPOUT then
            --断点判断
            isHit = self:isHitBreakpoint(info.source, info.orininal_source, info.currentline) or hitBP
            if isHit == true then
                self:printToVSCode("HitBreakpoint!")
                --备份信息
                local recordStepOverCounter = stepOverCounter
                local recordStepOutCounter = stepOutCounter
                local recordCurrentRunState = rstatus
                --计数器清0
                stepOverCounter = 0
                stepOutCounter = 0
                self:change_run_status(RunStatus.HIT_BREAKPOINT)
                hitBpTwiceCheck = true -- 命中标志默认设置为true, 如果校验通过，会保留这个标记，校验失败会修改
                if hitBP then 
                    hitBP = false --hitBP是断点硬性命中标记
                    --发消息并等待
                    self:SendMsgWithStack("stopOnCodeBreakpoint")
                else
                    --发消息并等待
                    self:SendMsgWithStack("stopOnBreakpoint")   
                    --若二次校验未命中，恢复状态
                    if hitBpTwiceCheck == false then 
                        isHit = false
                        -- 确认未命中，把状态恢复，继续运行
                        self:change_run_status(recordCurrentRunState)
                        stepOverCounter = recordStepOverCounter
                        stepOutCounter = recordStepOutCounter
                    end
                end
            end
        end
    end
    if isHit == true then
        return
    end
    if self.run_status == RunStatus.STEPOVER then
        -- line stepOverCounter!= 0 不作操作
        -- line stepOverCounter == 0 停止
        if event == "line" and stepOverCounter <= 0 then
            stepOverCounter = 0
            self:change_run_status(RunStatus.STEPOVER_STOP)
            self:SendMsgWithStack("stopOnStep")
        elseif event == "return" or event == "tail return" then
            if stepOverCounter ~= 0 then
                stepOverCounter = stepOverCounter - 1
            end
        elseif event == "call" then
            stepOverCounter = stepOverCounter + 1
        end
    elseif self.run_status == RunStatus.STOP_ON_ENTRY then
        if event == "line" then
            --这里要判断一下是Lua的入口点，否则停到
            self:SendMsgWithStack("stopOnEntry")
        end
    elseif self.run_status == RunStatus.STEPIN then
        if event == "line" then
            self:change_run_status(RunStatus.STEPIN_STOP)
            self:SendMsgWithStack("stopOnStepIn")
        end
    elseif self.run_status == RunStatus.STEPOUT then
        --line 不做操作
        --in 计数器+1
        --out 计数器-1
        if stepOutCounter <= -1 then
            stepOutCounter = 0
            self:change_run_status(RunStatus.STEPOUT_STOP)
            self:SendMsgWithStack("stopOnStepOut")
        end
        if event == "return" or event == "tail return" then
            stepOutCounter = stepOutCounter - 1
        elseif event == "call" then
            stepOutCounter = stepOutCounter + 1
        end
    end

    --在RUN时检查并改变状态
    if self.run_status == RunStatus.RUN and currentHookState ~= HookStatus.DISCONNECT_HOOK then
        local fileBP, G_BP = self:checkHasBreakpoint(lastRunFilePath)
        if fileBP == false then
            --文件无断点
            if G_BP == true then
                self:change_hook_status(HookStatus.MID_HOOK)
            else
                self:change_hook_status(HookStatus.LITE_HOOK)
            end
        else
            --文件有断点, 判断函数内是否有断点
            local funHasBP = self:checkfuncHasBreakpoint(lastRunFunction.linedefined, lastRunFunction.lastlinedefined, lastRunFilePath)
            if  funHasBP then
                --函数定义范围内
                self:change_hook_status(HookStatus.ALL_HOOK)
            else
                self:change_hook_status(HookStatus.MID_HOOK)
            end
        end

        --MID_HOOK状态下，return需要在下一次hook检查文件（return时，还是当前文件，检查文件时状态无法转换）
        if  (event == "return" or event == "tail return") and currentHookState == HookStatus.MID_HOOK then
            self:change_hook_status(HookStatus.ALL_HOOK)
        end
    end
end

quanta.luapanda = LuaPanda()

return LuaPanda
