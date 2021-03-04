--_listener.lua
local pcall     = pcall
local xpcall    = xpcall
local ipairs    = ipairs
local tpack     = table.pack
local tunpack   = table.unpack
local tinsert   = table.insert
local tdelete   = table_ext.delete
local log_err   = logger.err
local log_warn  = logger.warn
local dtraceback= debug.traceback

local Listener = class()
function Listener:__init()
    self._triggers = {}     -- map<event, {listener = true, ...}
    self._listeners = {}    -- map<event, listener>
    self._commands = {}     -- map<cmd, listener>
end

function Listener:add_trigger(trigger, event)
    if not self._triggers[event] then
        self._triggers[event] = {}
    end
    tinsert(self._triggers[event], trigger)
end

function Listener:remove_trigger(trigger, event)
    if self._triggers[event] then
        tdelete(self._triggers[event], trigger)
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

function Listener:add_cmd_listener(listener, cmd, event)
    if self._commands[cmd] then
        log_warn("[Listener][add_cmd_listener] cmd(%s) repeat!", cmd)
        return
    end
    self._commands[cmd] = {listener, event}
end

function Listener:remove_cmd_listener(cmd)
    self._commands[cmd] = nil
end

function Listener:notify_trigger(event, ...)
    for _, trigger in ipairs(self._triggers[event] or {}) do
        if trigger[event] then
            local ok, ret = xpcall(trigger[event], dtraceback, trigger, ...)
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
        log_err("[Listener][notify_listener] notify_listener event(%s) failed, because: %s, traceback:%s!", event, result[2], dtraceback())
    end
    return result
end

function Listener:notify_command(cmd, ...)
    local listener_ctx = self._commands[cmd]
    if not listener_ctx then
        log_warn("[Listener][notify_command] command %s handler is nil!", cmd)
        return tpack(false, "command handler is nil")
    end
    --执行事件
    local listener, event = tunpack(listener_ctx)
    if not listener[event] then
        log_err("[Listener][notify_command] command %s handler is nil!", cmd)
        return tpack(false, "command handler is nil")
    end
    local result = tpack(pcall(listener[event], listener, ...))
    if not result[1] then
        log_err("[Listener][notify_command] notify event(%s) failed, because: %s!, traceback:%s!", event, result[2], dtraceback())
    end
    return result
end

--创建全局监听器
quanta.event_mgr = Listener()

return Listener
