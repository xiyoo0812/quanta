--redis.lua
--luacheck: ignore

local lbus          = require("luabus")
local ljson         = require("lcjson")
local lcrypt        = require("lcrypt")
local Socket        = import("driver/socket.lua")

local log_err       = logger.err
local log_info      = logger.info
local tinsert       = table.insert
local jencode       = ljson.encode
local jdecode       = ljson.decode

local SPLIT_CHAR    = "|*|"
local NT_TIMEOUT    = quanta.enum("NetwkTime", "NETWORK_TIMEOUT")

local LuaPanda = singleton()
local prop = property(LuaPanda)
prop:reader("sock", nil)
prop:reader("session", nil)
prop:reader("state", "DISCONNECT")
prop:reader("breakpoints", {})
prop:reader("fake_breakpoints", {})

function LuaPanda:__init()
    self.sock = Socket()
end

function LuaPanda:setup(ip, port)
    self.sock:listen(ip, port)
end

function LuaPanda:close()
    if self.session then
        self.session:close()
    end
end

function LuaPanda:on_socket_accept(session, token)
    if self.session then
        self.session:close()
    end
    self.session = session
    self:change_state("WAIT_CMD")
end

function LuaPanda:on_socket_recv(session, token)
    while true do
        local response, length = session:peek_data(SPLIT_CHAR)
        if not line then
            break
        end
        session:pop(length)
        self:proc_response(response)
    end
end

function LuaPanda:on_socket_error(session, token, err)
    self.session = nil
end

function LuaPanda:build_msg(cmd, callback_id)
    return { cmd = cmd, info = {}, callbackId = callback_id or 0 }
end

function LuaPanda:send_msg(msg)
    self.sock:send(jencode(msg))
end

function LuaPanda:proc_response(response)
    local panda_data = jdecode(response)
    if not panda_data then
        self:print2vscode("[error] Json is error", 2)
        return
    end
    local cmd, callback_id = panda_data.cmd, panda_data.callbackId
    if cmd == "continue" then
        local info = panda_data.info
        if info.isFakeHit == "true" and info.fakeBKPath and info.fakeBKLine then 
            -- 设置校验结果标志位，以便hook流程知道结果
            hitBpTwiceCheck = false
            -- 把假断点的信息加入cache
            if not self.fake_breakpoints[info.fakeBKPath] then
                self.fake_breakpoints[info.fakeBKPath] = {}
            end
            tinsert(self.fake_breakpoints[info.fakeBKPath], info.fakeBKLine)
        else
            self:change_state("RUN")
        end
        self:send_msg(self:build_msg(cmd, callback_id))
    elseif cmd == "stopOnStep" then
        self:change_state("STEPOVER")
        self:send_msg(self:build_msg(cmd, callback_id))
        self:changeHookState("ALL_HOOK")
    elseif cmd == "stopOnStepIn" then
        self:change_state("STEPIN")
        self:send_msg(self:build_msg(cmd, callback_id))
        self:changeHookState("ALL_HOOK")
    elseif cmd == "stopOnStepOut" then
        self:change_state("STEPOUT")
        self:send_msg(self:build_msg(cmd, callback_id))
        self:changeHookState("ALL_HOOK")
    elseif cmd == "setBreakPoint" then
        self:print2vscode("panda_data.cmd == setBreakPoint")
        -- 设置断点时，把 fake_breakpoints 清空。这是一个简单的做法，也可以清除具体的条目
        self.fake_breakpoints = {}
        local bkPath = panda_data.info.path
        bkPath = self:genUnifiedPath(bkPath)
        local short_path = bkPath
        if autoPathMode then 
            -- 自动路径模式下，仅保留文件名
            -- table[文件名.后缀] -- [fullpath] -- [line , type]
            --                  | - [fullpath] -- [line , type]
            short_path = self:getFilenameFromPath(bkPath)
        end
        if self.breakpoints[short_path] == nil then 
            self.breakpoints[short_path] = {}
        end
        self.breakpoints[short_path][bkPath] = panda_data.info.bks
        -- 当v为空时，从断点列表中去除文件
        for k, v in pairs(self.breakpoints[short_path]) do
            if not next(v) then
                self.breakpoints[short_path][k] = nil
            end
        end
        -- 当v为空时，从断点列表中去除文件
        for k, v in pairs(self.breakpoints) do
            if not next(v) then
                self.breakpoints[k] = nil
            end
        end
        if self.state ~= "WAIT_CMD" then
            local fileBP, G_BP =self:checkHasBreakpoint(lastRunFilePath)
            if fileBP == false then
                if G_BP == true then
                    self:changeHookState("MID_HOOK")
                else
                    self:changeHookState("LITE_HOOK")
                end
            else
                self:changeHookState("ALL_HOOK")
            end
        end
        self:send_msg(self:build_msg(cmd, callback_id))
        self:print2vscode("self:getInfo()\n" .. self:getInfo())
    elseif cmd == "setVariable" then
        if self.state == "STOP_ON_ENTRY" or self.state == "HIT_BREAKPOINT" or
            self.state == "STEPOVER_STOP" or self.state == "STEPIN_STOP" or self.state == "STEPOUT_STOP" then
            local resmsg = self:build_msg(cmd, callback_id)
            local resmsg = self:getMsgTable("setVariable", self:getCallbackId())
            local varRefNum = tonumber(panda_data.info.varRef)
            local newValue = tostring(panda_data.info.newValue)
            local needFindVariable = true    --如果变量是基础类型，直接赋值，needFindVariable = false 如果变量是引用类型，needFindVariable = true
            local varName = tostring(panda_data.info.varName)
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
            if panda_data.info.stackId ~= nil and tonumber(panda_data.info.stackId) ~= nil and tonumber(panda_data.info.stackId) > 1 then
                self.curStackId = tonumber(panda_data.info.stackId)
            else
                self:printToVSCode("未能获取到堆栈层级，默认使用 self.curStackId")
            end

            if varRefNum < 10000 then
                -- 如果修改的是一个 引用变量，那么可直接赋值。但还是要走变量查询过程。查找和赋值过程都需要steakId。 目前给引用变量赋值Object，steak可能有问题
                resmsg.info = self:createSetValueRetTable(varName, newValue, needFindVariable, self.curStackId, variableRefTab[varRefNum])
            else
                -- 如果修改的是一个基础类型
                local setLimit --设置检索变量的限定区域
                if varRefNum >= 10000 and varRefNum < 20000 then setLimit = "local"
                elseif varRefNum >= 20000 and varRefNum < 30000 then setLimit = "global"
                elseif varRefNum >= 30000 then setLimit = "upvalue"
                end
                resmsg.info = self:createSetValueRetTable(varName, newValue, needFindVariable, self.curStackId, nil, setLimit)
            end

            self:send_msg(resmsg)
        end
    elseif cmd == "getVariable" then
        --仅在停止时处理消息，其他时刻收到此消息，丢弃
        if self.state == "STOP_ON_ENTRY" or self.state == "HIT_BREAKPOINT" or
            self.state == "STEPOVER_STOP" or self.state == "STEPIN_STOP" or self.state == "STEPOUT_STOP" then
            --发送变量给游戏，并保持之前的状态,等待再次接收数据
            --panda_data.info.varRef  10000~20000局部变量
            --                       20000~30000全局变量
            --                       30000~     upvalue
            -- 1000~2000局部变量的查询，2000~3000全局，3000~4000upvalue
            local msgTab = self:getMsgTable("getVariable", self:getCallbackId())
            local varRefNum = tonumber(panda_data.info.varRef)
            if varRefNum < 10000 then
                --查询变量, 此时忽略 stackId
                local varTable = self:getVariableRef(panda_data.info.varRef, true)
                msgTab.info = varTable
            elseif varRefNum >= 10000 and varRefNum < 20000 then
                --局部变量
                if panda_data.info.stackId ~= nil and tonumber(panda_data.info.stackId) > 1 then
                    self.curStackId = tonumber(panda_data.info.stackId)
                    if type(currentCallStack[self.curStackId - 1]) ~= "table" or  type(currentCallStack[self.curStackId - 1].func) ~= "function" then
                        local str = "getVariable getLocal currentCallStack " .. self.curStackId - 1   .. " Error\n" .. self:serializeTable(currentCallStack, "currentCallStack")
                        self:printToVSCode(str, 2)
                        msgTab.info = {}
                    else
                        local stackId = self:getSpecificFunctionStackLevel(currentCallStack[self.curStackId - 1].func) --去除偏移量
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
                if panda_data.info.stackId ~= nil and tonumber(panda_data.info.stackId) > 1 then
                    self.curStackId = tonumber(panda_data.info.stackId)
                    if type(currentCallStack[self.curStackId - 1]) ~= "table" or  type(currentCallStack[self.curStackId - 1].func) ~= "function" then
                        local str = "getVariable getUpvalue currentCallStack " .. self.curStackId - 1   .. " Error\n" .. self:serializeTable(currentCallStack, "currentCallStack")
                        self:printToVSCode(str, 2)
                        msgTab.info = {}
                    else
                        local varTable = self:getUpValueVariable(currentCallStack[self.curStackId - 1 ].func, true)
                        msgTab.info = varTable
                    end
                end
            end
            self:sendMsg(msgTab)
            self:debugger_wait_msg()
        end
    elseif cmd == "initSuccess" then
        --初始化会传过来一些变量，这里记录这些变量
        --Base64
        if panda_data.info.isNeedB64EncodeStr == "true" then
            isNeedB64EncodeStr = true
        else
            isNeedB64EncodeStr = false
        end
        --path
        luaFileExtension = panda_data.info.luaFileExtension
        local TempFilePath = panda_data.info.TempFilePath
        if TempFilePath:sub(-1, -1) == [[\]] or TempFilePath:sub(-1, -1) == [[/]] then
            TempFilePath = TempFilePath:sub(1, -2)
        end
        TempFilePath_luaString = TempFilePath
        cwd = self:genUnifiedPath(panda_data.info.cwd)
        --logLevel
        logLevel = tonumber(panda_data.info.logLevel) or 1
        --autoPathMode
        if panda_data.info.autoPathMode == "true" then
            autoPathMode = true
        else
            autoPathMode = false
        end
        if  panda_data.info.pathCaseSensitivity == "true" then
            pathCaseSensitivity =  true
            truncatedOPath = panda_data.info.truncatedOPath or ""
        else
            pathCaseSensitivity =  false
            truncatedOPath = string.lower(panda_data.info.truncatedOPath or "")
        end
        if  panda_data.info.distinguishSameNameFile == "true" then
            distinguishSameNameFile =  true
        else
            distinguishSameNameFile =  false
        end
        --OS type
        if not OSType then
            --用户未主动设置OSType, 接收VSCode传来的数据
            if type(panda_data.info.OSType) == "string" then 
                OSType = panda_data.info.OSType
            else
                OSType = "Windows_NT"
                OSTypeErrTip = "未能检测出OSType, 可能是node os库未能加载，系统使用默认设置Windows_NT"
            end
        end
        --检测用户是否自设了clib路径
        isUserSetClibPath = false
        if nil == clibPath then
            --用户未设置clibPath, 接收VSCode传来的数据
            if type(panda_data.info.clibPath) == "string" then  
                clibPath = panda_data.info.clibPath
            else 
                clibPath = "" 
                pathErrTip = "未能正确获取libpdebug库所在位置, 可能无法加载libpdebug库。"
            end
        else
            --用户自设clibPath
            isUserSetClibPath = true
        end
        --adapter版本信息
        adapterVer = tostring(panda_data.info.adapterVersion)
        local msgTab = self:getMsgTable("initSuccess", self:getCallbackId())
        --detect LoadString
        isUseLoadstring = 0
        if debugger_loadString ~= nil and type(debugger_loadString) == "function" then
            if(pcall(debugger_loadString("return 0"))) then
                isUseLoadstring = 1
            end
        end
        local tab = { debuggerVer = tostring(debuggerVer) , UseHookLib = tostring(isUseHookLib) , UseLoadstring = tostring(isUseLoadstring), isNeedB64EncodeStr = tostring(isNeedB64EncodeStr) }
        msgTab.info  = tab
        self:sendMsg(msgTab)
        --上面getBK中会判断当前状态是否WAIT_CMD, 所以最后再切换状态。
        stopOnEntry = panda_data.info.stopOnEntry
        if panda_data.info.stopOnEntry == "true" then
            self:change_state("STOP_ON_ENTRY")   --停止在STOP_ON_ENTRY再接收breaks消息
        else
            self:debugger_wait_msg(1)  --等待1s bk消息 如果收到或超时(没有断点)就开始运行
            self:change_state("RUN")
        end
    elseif panda_data.cmd == "getWatchedVariable" then
        local msgTab = self:getMsgTable("getWatchedVariable", self:getCallbackId())
        local stackId = tonumber(panda_data.info.stackId)
        --loadstring系统函数, watch插件加载
        if isUseLoadstring == 1 then
            --使用loadstring
            self.curStackId = stackId
            local retValue = self:processWatchedExp(panda_data.info)
            msgTab.info = retValue
            self:sendMsg(msgTab)
            self:debugger_wait_msg()
            return
        else
            --旧的查找方式
            local wv =  self:getWatchedVariable(panda_data.info.varName, stackId, true)
            if wv ~= nil then
                msgTab.info = wv
            end
            self:sendMsg(msgTab)
            self:debugger_wait_msg()
        end
    elseif panda_data.cmd == "stopRun" then
        --停止hook，已不在处理任何断点信息，也就不会产生日志等。发送消息后等待前端主动断开连接
        local msgTab = self:getMsgTable("stopRun", self:getCallbackId())
        self:sendMsg(msgTab)
        if not luaProcessAsServer then
            self:disconnect()
        end
    elseif "LuaGarbageCollect" == panda_data.cmd then
        self:printToVSCode("collect garbage!")
        collectgarbage("collect")
        --回收后刷一下内存
        self:sendLuaMemory()
        self:debugger_wait_msg()
    elseif "runREPLExpression" == panda_data.cmd then
        self.curStackId = tonumber(panda_data.info.stackId)
        local retValue = self:processExp(panda_data.info)
        local msgTab = self:getMsgTable("runREPLExpression", self:getCallbackId())
        msgTab.info = retValue
        self:sendMsg(msgTab)
        self:debugger_wait_msg()
    else
    end
end

function LuaPanda:change_state(state)
    self.state = state
end

function LuaPanda:print2vscode(log)
end

return LuaPanda
