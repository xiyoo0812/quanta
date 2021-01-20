--_listener.lua
local pairs     = pairs
local pcall     = pcall
local xpcall    = xpcall
local tpack     = table.pack
local tunpack   = table.unpack
local log_err   = logger.err
local log_warn  = logger.warn

local Listener = class()
function Listener:__init()
    self._triggers = {}     -- map<event, {listener = true, ...}
    self._listeners = {}    -- map<event, listener>
    self._commands = {}     -- map<cmd, listener>
    self._verifers = {}     -- map<cmd, verifier>
end

function Listener:add_trigger(trigger, event)
    if not self._triggers[event] then
        self._triggers[event] = {}
    end
    self._triggers[event][trigger] = true
end

function Listener:remove_trigger(trigger, event)
    if self._triggers[event] then
        self._triggers[event][trigger] = nil
    end
end

function Listener:add_listener(listener, event)
    if self._listeners[event] then
        log_warn("[Listener][add_listener] event(%s) repeat!", event)
        return
    end
    self._listeners[event] = listener
end

function Listener:remove_listener(event)
    self._listeners[event] = nil
end

function Listener:add_cmd_listener(listener, cmd, event, verifier)
    if self._commands[cmd] then
        log_warn("[Listener][add_cmd_listener] cmd(%s) repeat!", cmd)
        return
    end
    self._commands[cmd] = {listener, event}
    if verifier then
        self._verifers[cmd] = {verifier, event}
    end
end

function Listener:remove_cmd_listener(cmd)
    self._commands[cmd] = nil
    self._verifers[cmd] = nil
end

function Listener:notify_trigger(event, ...)
    for trigger in pairs(self._triggers[event] or {}) do
        if trigger[event] then
            local ok, ret = xpcall(trigger[event], debug.traceback, trigger, ...)
            if not ok then
                log_err("[Listener][notify_listener] xpcall %s:%s failed, err : %s!", trigger, event, ret)
            end
        end
    end
end

function Listener:notify_listener(event, ...)
    local listener = self._listeners[event]
    if not listener or not listener[event] then
        log_warn("[Listener][notify_listener] event %s handler is nil!", event)
        return tpack(false, "event handler is nil")
    end
    local result = tpack(pcall(listener[event], listener, ...))
    if not result[1] then
        log_err("[Listener][notify_listener] notify_listener event(%s) failed, because: %s!", event, result[2])
    end
    return result
end

function Listener:notify_command(cmd, ...)
    local listener_ctx = self._commands[cmd]
    if not listener_ctx then
        log_warn("[Listener][notify_command] command %s handler is nil!", cmd)
        return tpack(false, "command handler is nil")
    end
    --校验参数
    local verifier_ctx = self._verifers[cmd]
    if verifier_ctx then
        local verifier, event = tunpack(verifier_ctx)
        if verifier[event] then
            local ok, code = pcall(verifier[event], verifier, ...)
            if not ok  then
                return tpack(false, "verify handler exec failed")
            end
            if code ~= 0 then
                return tpack(true, {code = code})
            end
        end
    end
    --执行事件
    local listener, event = tunpack(listener_ctx)
    if not listener[event] then
        log_err("[Listener][notify_command] command %s handler is nil!", cmd)
        return tpack(false, "command handler is nil")
    end
    local result = tpack(pcall(listener[event], listener, ...))
    if not result[1] then
        log_err("[Listener][notify_command] notify event(%s) failed, because: %s!", event, result[2])
    end
    return result
end

--创建全局监听器
quanta.event_mgr = Listener()

return Listener
