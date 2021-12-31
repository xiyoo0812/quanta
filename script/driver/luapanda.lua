--luapanda.lua
--集成腾讯LuaPanda调试工具
local ljson         = require("lcjson")
local QueueFIFO     = import("container/queue_fifo.lua")

local log_err       = logger.err
local log_info      = logger.info
local sformat       = string.format
local json_encode   = ljson.encode
local json_decode   = ljson.decode
local tinsert       = table.insert
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
prop:reader("messages", nil)        --收到的消息列表
prop:reader("callback_id", 0)       --callback_id
prop:reader("call_stacks", {})      --获取当前调用堆栈信息
prop:reader("hitbp_check", true)    --命中断点的Vscode校验结果，默认true (true是命中，false是未命中)
prop:reader("var_ref_idx", 1)       --变量索引
prop:reader("var_ref_tab", {})      --变量记录table
prop:reader("fake_bp_cache", {})    --其中用 路径-{行号列表} 形式保存错误命中信息
prop:reader("fmt_path_cache", {})   --getinfo -> format



prop:reader("run_status", RunStatus.DISCONNECT)
prop:reader("hook_status", HookStatus.DISCONNECT_HOOK)
function LuaPanda:__init()
    self.messages = QueueFIFO()
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
    self:send_message(message)
end

-- 向adapter发消息
function LuaPanda:send_message(message)
    if self.run_status == RunStatus.DISCONNECT then
        self:detach()
        return
    end
    self.socket:send(sformat("%s|*|\n", json_encode(message)))
end

function LuaPanda:on_socket_recv(socket, token)
    while true do
        local message, length = socket:peek_data("|*|")
        if not message then
            break
        end
        self.messages:push(message)
        sock:pop(length)
    end
end

-- 运行状态变更
function LuaPanda:change_run_status(status)
    self.run_status = status
    --状态切换时，清除记录栈信息的状态
    self.var_ref_idx = 1
    self.call_stacks = {}
    self.var_ref_tab = {}
end

--改变hook状态
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

--改变协程hook状态
function LuaPanda:change_cos_hook_status()
    local coroutine_pool = thread_mgr:get_coroutine_pool()
    for _, co in coroutine_pool:iter() do
        self:change_co_hook_status(co)
    end
end

--改变协程hook状态
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

--这里维护一个接收消息队列
function LuaPanda:receive_message()
    --如果队列中还有消息，直接取出来交给data_process处理
    if not self.messages:empty() then
        local saved_cmd = self.messages:pop()
        self:data_process(saved_cmd)
        return true
    end
    if self.run_status == RunStatus.DISCONNECT then
        self:disconnect()
        return false
    end
end

--这里不用循环，在外面处理完消息会在调用回来
function LuaPanda:debugger_wait_msg()
    if self.run_status == RunStatus.WAIT_CMD then
        if not self.messages:empty() then
            local message = self.messages:pop()
            self:data_process(message)
        end
    end
end

-- 处理 收到的消息
function LuaPanda:data_process( message )
    self:output2vscode("debugger get:" .. message)
    local dataTable = json_decode(message)
    if not dataTable then
        self:output2vscode("[error] Json is error", "debug_console")
        return
    end
    if dataTable.callbackId ~= "0" then
        self:set_callback_id(dataTable.callbackId)
    end
    if dataTable.cmd == "continue" then
        local info = dataTable.info
        local fake_path, fake_line = info.fakeBKPath, info.fakeBKLine
        if info.isFakeHit == "true" and fake_path and fake_line then 
            -- 设置校验结果标志位，以便hook流程知道结果
            self.hitbp_check = false
            -- 把假断点的信息加入cache
            if not self.fake_bp_cache[fake_path] then
                self.fake_bp_cache[fake_path] = {}
            end
            tinsert(self.fake_bp_cache[fake_path], fake_line)
        else
            self:change_run_status(RunStatus.RUN)
        end
        local msgTab = self:getMsgTable("continue", self:get_callback_id())
        self:send_message(msgTab)

    elseif dataTable.cmd == "stopOnStep" then
        self:change_run_status(RunStatus.STEPOVER)
        local msgTab = self:getMsgTable("stopOnStep", self:get_callback_id())
        self:send_message(msgTab)
        self:change_hook_status(HookStatus.ALL_HOOK)
    elseif dataTable.cmd == "stopOnStepIn" then
        self:change_run_status(RunStatus.STEPIN)
        local msgTab = self:getMsgTable("stopOnStepIn", self:get_callback_id())
        self:send_message(msgTab)
        self:change_hook_status(HookStatus.ALL_HOOK)
    elseif dataTable.cmd == "stopOnStepOut" then
        self:change_run_status(RunStatus.STEPOUT)
        local msgTab = self:getMsgTable("stopOnStepOut", self:get_callback_id())
        self:send_message(msgTab)
        self:change_hook_status(HookStatus.ALL_HOOK)
    elseif dataTable.cmd == "setBreakPoint" then
        self:output2vscode("dataTable.cmd == setBreakPoint")
        -- 设置断点时，把 self.fake_bp_cache 清空。这是一个简单的做法，也可以清除具体的条目
        self.fake_bp_cache = {}
        local bkPath = dataTable.info.path
        bkPath = self:genUnifiedPath(bkPath)
        if testBreakpointFlag then
            recordBreakPointPath = bkPath
        end
        if autoPathMode then 
            -- 自动路径模式下，仅保留文件名
            -- table[文件名.后缀] -- [fullpath] -- [line , type]
            --                  | - [fullpath] -- [line , type]
            local bkShortPath = self:getFilenameFromPath(bkPath)
            if breaks[bkShortPath] == nil then 
                breaks[bkShortPath] = {}
            end
            breaks[bkShortPath][bkPath] = dataTable.info.bks
            -- 当v为空时，从断点列表中去除文件
            for k, v in pairs(breaks[bkShortPath]) do
                if next(v) == nil then
                    breaks[bkShortPath][k] = nil
                end
            end
        else
            if breaks[bkPath] == nil then 
                breaks[bkPath] = {}
            end
            -- 两级 bk path 是为了和自动路径模式结构保持一致
            breaks[bkPath][bkPath] = dataTable.info.bks
            -- 当v为空时，从断点列表中去除文件
            for k, v in pairs(breaks[bkPath]) do
                if next(v) == nil then
                    breaks[bkPath][k] = nil
                end
            end
        end
        -- 当v为空时，从断点列表中去除文件
        for k, v in pairs(breaks) do
            if next(v) == nil then
                breaks[k] = nil
            end
        end
        if self.run_status ~= RunStatus.WAIT_CMD then
            if hookLib == nil then
                local fileBP, G_BP =self:checkHasBreakpoint(lastRunFilePath)
                if fileBP == false then
                    if G_BP == true then
                        self:change_hook_status(HookStatus.MID_HOOK)
                    else
                        self:change_hook_status(HookStatus.LITE_HOOK)
                    end
                else
                    self:change_hook_status(HookStatus.ALL_HOOK)
                end
            end
        else
            local msgTab = self:getMsgTable("setBreakPoint", self:get_callback_id())
            self:send_message(msgTab)
            return
        end
        --其他时机收到breaks消息
        local msgTab = self:getMsgTable("setBreakPoint", self:get_callback_id())
        self:send_message(msgTab)
        -- 打印调试信息
        self:output2vscode("LuaPanda.getInfo()\n" .. self:getInfo())
        self:debugger_wait_msg()
    elseif dataTable.cmd == "setVariable" then
        if self.run_status == RunStatus.STOP_ON_ENTRY or
            self.run_status == RunStatus.HIT_BREAKPOINT or
            self.run_status == RunStatus.STEPOVER_STOP or
            self.run_status == RunStatus.STEPIN_STOP or
            self.run_status == RunStatus.STEPOUT_STOP then
            local msgTab = self:getMsgTable("setVariable", self:get_callback_id())
            local varRefNum = tonumber(dataTable.info.varRef)
            local newValue = tostring(dataTable.info.newValue)
            local needFindVariable = true    --如果变量是基础类型，直接赋值，needFindVariable = false 如果变量是引用类型，needFindVariable = true
            local varName = tostring(dataTable.info.varName)
            -- 根据首末含有" ' 判断 newValue 是否是字符串
            local first_chr = string.sub(newValue, 1, 1)
            local end_chr = string.sub(newValue, -1, -1)
            if first_chr == end_chr then
                if first_chr == "'" or first_chr == '"' then
                    newValue = string.sub(newValue, 2, -2)
                    needFindVariable = false
                end
            end
            --数字，nil，false，true的处理
            if newValue == "nil" and needFindVariable == true  then newValue = nil needFindVariable = false
            elseif newValue == "true" and needFindVariable == true then newValue = true needFindVariable = false
            elseif newValue == "false" and needFindVariable == true then newValue = false needFindVariable = false
            elseif tonumber(newValue) and needFindVariable == true then newValue = tonumber(newValue) needFindVariable = false
            end

            -- 如果新值是基础类型，则不需遍历
            if dataTable.info.stackId ~= nil and tonumber(dataTable.info.stackId) ~= nil and tonumber(dataTable.info.stackId) > 1 then
                self:curStackId = tonumber(dataTable.info.stackId)
            else
                self:output2vscode("未能获取到堆栈层级，默认使用 self:curStackId")
            end

            if varRefNum < 10000 then
                -- 如果修改的是一个 引用变量，那么可直接赋值。但还是要走变量查询过程。查找和赋值过程都需要steakId。 目前给引用变量赋值Object，steak可能有问题
                msgTab.info = self:createSetValueRetTable(varName, newValue, needFindVariable, self:curStackId, variableRefTab[varRefNum])
            else
                -- 如果修改的是一个基础类型
                local setLimit --设置检索变量的限定区域
                if varRefNum >= 10000 and varRefNum < 20000 then setLimit = "local"
                elseif varRefNum >= 20000 and varRefNum < 30000 then setLimit = "global"
                elseif varRefNum >= 30000 then setLimit = "upvalue"
                end
                msgTab.info = self:createSetValueRetTable(varName, newValue, needFindVariable, self:curStackId, nil, setLimit)
            end

            self:send_message(msgTab)
            self:debugger_wait_msg()
        end

    elseif dataTable.cmd == "getVariable" then
        --仅在停止时处理消息，其他时刻收到此消息，丢弃
        if self.run_status == RunStatus.STOP_ON_ENTRY or
        self.run_status == RunStatus.HIT_BREAKPOINT or
        self.run_status == RunStatus.STEPOVER_STOP or
        self.run_status == RunStatus.STEPIN_STOP or
        self.run_status == RunStatus.STEPOUT_STOP then
            --发送变量给游戏，并保持之前的状态,等待再次接收数据
            --dataTable.info.varRef  10000~20000局部变量
            --                       20000~30000全局变量
            --                       30000~     upvalue
            -- 1000~2000局部变量的查询，2000~3000全局，3000~4000upvalue
            local msgTab = self:getMsgTable("getVariable", self:get_callback_id())
            local varRefNum = tonumber(dataTable.info.varRef)
            if varRefNum < 10000 then
                --查询变量, 此时忽略 stackId
                local varTable = self:getVariableRef(dataTable.info.varRef, true)
                msgTab.info = varTable
            elseif varRefNum >= 10000 and varRefNum < 20000 then
                --局部变量
                if dataTable.info.stackId ~= nil and tonumber(dataTable.info.stackId) > 1 then
                    self:curStackId = tonumber(dataTable.info.stackId)
                    if type(currentCallStack[self:curStackId - 1]) ~= "table" or  type(currentCallStack[self:curStackId - 1].func) ~= "function" then
                        local str = "getVariable getLocal currentCallStack " .. self:curStackId - 1   .. " Error\n" .. self:serializeTable(currentCallStack, "currentCallStack")
                        self:output2vscode(str, 2)
                        msgTab.info = {}
                    else
                        local stackId = self:getSpecificFunctionStackLevel(currentCallStack[self:curStackId - 1].func) --去除偏移量
                        local varTable = self:getVariable(stackId, true)
                        msgTab.info = varTable
                    end
                end

            elseif varRefNum >= 20000 and varRefNum < 30000 then
                --全局变量
                local varTable = self:getGlobalVariable()
                msgTab.info = varTable
            elseif varRefNum >= 30000 then
                --upValue
                if dataTable.info.stackId ~= nil and tonumber(dataTable.info.stackId) > 1 then
                    self:curStackId = tonumber(dataTable.info.stackId)
                    if type(currentCallStack[self:curStackId - 1]) ~= "table" or  type(currentCallStack[self:curStackId - 1].func) ~= "function" then
                        local str = "getVariable getUpvalue currentCallStack " .. self:curStackId - 1   .. " Error\n" .. self:serializeTable(currentCallStack, "currentCallStack")
                        self:output2vscode(str, 2)
                        msgTab.info = {}
                    else
                        local varTable = self:getUpValueVariable(currentCallStack[self:curStackId - 1 ].func, true)
                        msgTab.info = varTable
                    end
                end
            end
            self:send_message(msgTab)
            self:debugger_wait_msg()
        end
    elseif dataTable.cmd == "initSuccess" then
        --初始化会传过来一些变量，这里记录这些变量
        --path
        luaFileExtension = dataTable.info.luaFileExtension
        local TempFilePath = dataTable.info.TempFilePath
        if TempFilePath:sub(-1, -1) == [[\]] or TempFilePath:sub(-1, -1) == [[/]] then
            TempFilePath = TempFilePath:sub(1, -2)
        end
        TempFilePath_luaString = TempFilePath
        cwd = self:genUnifiedPath(dataTable.info.cwd)
        --logLevel
        logLevel = tonumber(dataTable.info.logLevel) or 1
        --autoPathMode
        if dataTable.info.autoPathMode == "true" then
            autoPathMode = true
        else
            autoPathMode = false
        end
        if  dataTable.info.pathCaseSensitivity == "true" then
            pathCaseSensitivity =  true
            truncatedOPath = dataTable.info.truncatedOPath or ""
        else
            pathCaseSensitivity =  false
            truncatedOPath = string.lower(dataTable.info.truncatedOPath or "")
        end
        if  dataTable.info.distinguishSameNameFile == "true" then
            distinguishSameNameFile =  true
        else
            distinguishSameNameFile =  false
        end
        --用户未主动设置OSType, 接收VSCode传来的数据
        if type(dataTable.info.OSType) == "string" then 
            OSType = dataTable.info.OSType
        else
            OSType = "Windows_NT"
            OSTypeErrTip = "未能检测出OSType, 可能是node os库未能加载，系统使用默认设置Windows_NT"
        end
        --adapter版本信息
        local msgTab = self:getMsgTable("initSuccess", self:get_callback_id())
        msgTab.info  = { debuggerVer = tostring(debuggerVer) , UseHookLib = 0, UseLoadstring = 0, isNeedB64EncodeStr = 0 }
        self:send_message(msgTab)
        --上面getBK中会判断当前状态是否WAIT_CMD, 所以最后再切换状态。
        stopOnEntry = dataTable.info.stopOnEntry
        if dataTable.info.stopOnEntry == "true" then
            self:change_run_status(RunStatus.STOP_ON_ENTRY)   --停止在STOP_ON_ENTRY再接收breaks消息
        else
            self:debugger_wait_msg(1)  --等待1s bk消息 如果收到或超时(没有断点)就开始运行
            self:change_run_status(RunStatus.RUN)
        end
    elseif dataTable.cmd == "getWatchedVariable" then
        local msgTab = self:getMsgTable("getWatchedVariable", self:get_callback_id())
        local stackId = tonumber(dataTable.info.stackId)
        --使用loadstring
        self:curStackId = stackId
        local retValue = self:processWatchedExp(dataTable.info)
        msgTab.info = retValue
        self:send_message(msgTab)
        self:debugger_wait_msg()
    elseif dataTable.cmd == "stopRun" then
        --停止hook，已不在处理任何断点信息，也就不会产生日志等。发送消息后等待前端主动断开连接
        local msgTab = self:getMsgTable("stopRun", self:get_callback_id())
        self:send_message(msgTab)
        if not luaProcessAsServer then
            self:disconnect()
        end
    elseif "LuaGarbageCollect" == dataTable.cmd then
        self:output2vscode("collect garbage!")
        collectgarbage("collect")
        --回收后刷一下内存
        self:sendLuaMemory()
        self:debugger_wait_msg()
    elseif "runREPLExpression" == dataTable.cmd then
        self:curStackId = tonumber(dataTable.info.stackId)
        local retValue = self:processExp(dataTable.info)
        local msgTab = self:getMsgTable("runREPLExpression", self:get_callback_id())
        msgTab.info = retValue
        self:send_message(msgTab)
        self:debugger_wait_msg()
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
            self:debugger_wait_msg()
            self.last_tick = ti
        end
        return
    end
    --运行中
    local co, is_main = coroutine.running()
    local info = is_main and dgetinfo(2, "Slf") or dgetinfo(co, 2, "Slf")
    --不处理C函数
    if info.source == "=[C]" then
        return
    end
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
            self:debugger_wait_msg()
            self.last_tick = ti
        end
    end
    --使用 info.orininal_source 记录lua虚拟机传来的原始路径
    info.orininal_source = info.source
    --标准路径处理
    info.source = self:getPath(info)
    --本次执行的函数和上次执行的函数作对比，防止在一行停留两次
    if lastRunFunction["currentline"] == info["currentline"] and lastRunFunction["source"] == info["source"] and lastRunFunction["func"] == info["func"] and lastRunFunction["event"] == event then
        self:output2vscode("run twice")
    end
    --记录最后一次调用信息
    lastRunFunction = info
    lastRunFunction["event"] = event
    lastRunFilePath = info.source

    --仅在line时做断点判断。进了断点之后不再进入本次STEP类型的判断，用Aflag做标记
    local isHit = false
    if event == "line" then
        if rstatus == RunStatus.RUN or rstatus == RunStatus.STEPOVER or rstatus == RunStatus.STEPIN or rstatus == RunStatus.STEPOUT then
            --断点判断
            isHit = self:isHitBreakpoint(info.source, info.orininal_source, info.currentline) or hitBP
            if isHit == true then
                self:output2vscode("HitBreakpoint!")
                --备份信息
                local recordStepOverCounter = stepOverCounter
                local recordStepOutCounter = stepOutCounter
                local recordCurrentRunState = rstatus
                --计数器清0
                stepOverCounter = 0
                stepOutCounter = 0
                self:change_run_status(RunStatus.HIT_BREAKPOINT)
                self.hitbp_check = true -- 命中标志默认设置为true, 如果校验通过，会保留这个标记，校验失败会修改
                if hitBP then 
                    hitBP = false --hitBP是断点硬性命中标记
                    --发消息并等待
                    self:SendMsgWithStack("stopOnCodeBreakpoint")
                else
                    --发消息并等待
                    self:SendMsgWithStack("stopOnBreakpoint")   
                    --若二次校验未命中，恢复状态
                    if self.hitbp_check == false then 
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
    if self.run_status == RunStatus.RUN and self.hook_status ~= HookStatus.DISCONNECT_HOOK then
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
        if  (event == "return" or event == "tail return") and self.hook_status == HookStatus.MID_HOOK then
            self:change_hook_status(HookStatus.ALL_HOOK)
        end
    end
end

quanta.luapanda = LuaPanda()

return LuaPanda
