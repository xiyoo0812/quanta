--listener.lua
local xpcall    = xpcall
local tpack     = table.pack
local sformat   = string.format
local qtweak    = qtable.weak
local log_warn  = logger.warn
local log_fatal = logger.fatal
local dtraceback= debug.traceback

local Listener = class()
function Listener:__init()
    self._triggers = {}     -- map<event, {[listener] = func_name, ...}
    self._listeners = {}    -- map<event, {[listener] = func_name}
    self._commands = {}     -- map<cmd, {[listener] = func_name}
    self._ignores = {}      -- map<cmd, bool>
end

function Listener:add_trigger(trigger, event, handler)
    local func_name = handler or event
    local callback_func = trigger[func_name]
    if not callback_func or type(callback_func) ~= "function" then
        log_warn("[Listener][add_trigger] event(%s) handler not define", event)
        return
    end
    local trigger_map = self._triggers[event]
    if not trigger_map then
        self._triggers[event] = qtweak({ [trigger] = func_name })
        return
    end
    trigger_map[trigger] = func_name
end

function Listener:remove_trigger(trigger, event)
    local trigger_map = self._triggers[event]
    if trigger_map then
        trigger_map[trigger] = nil
    end
end

function Listener:add_listener(listener, event, handler)
    if self._listeners[event] then
        log_warn("[Listener][add_listener] event(%s) repeat!", event)
        return
    end
    local func_name = handler or event
    local callback_func = listener[func_name]
    if not callback_func or type(callback_func) ~= "function" then
        log_warn("[Listener][add_listener] event(%s) callback not define!", event)
        return
    end
    self._listeners[event] = qtweak({ [listener] = func_name })
end

function Listener:remove_listener(event)
    self._listeners[event] = nil
end

function Listener:add_cmd_listener(listener, cmd, handler)
    if self._commands[cmd] then
        log_warn("[Listener][add_cmd_listener] cmd(%s) repeat!", cmd)
        return
    end
    local func_name = handler
    local callback_func = listener[func_name]
    if not callback_func or type(callback_func) ~= "function" then
        log_warn("[Listener][add_cmd_listener] cmd(%s) handler not define!", cmd)
        return
    end
    self._commands[cmd] = qtweak({ [listener] = func_name })
end

function Listener:remove_cmd_listener(cmd)
    self._commands[cmd] = nil
end

function Listener:notify_trigger(event, ...)
    local trigger_map = self._triggers[event] or {}
    for trigger, func_name in pairs(trigger_map) do
        local callback_func = trigger[func_name]
        local ok, ret = xpcall(callback_func, dtraceback, trigger, ...)
        if not ok then
            log_fatal("[Listener][notify_trigger] xpcall [%s:%s] failed: %s!", trigger:source(), func_name, ret)
        end
    end
end

function Listener:notify_listener(event, ...)
    local listener_map = self._listeners[event] or {}
    for listener, func_name in pairs(listener_map) do
        local callback_func = listener[func_name]
        local result = tpack(xpcall(callback_func, dtraceback, listener, ...))
        if not result[1] then
            log_fatal("[Listener][notify_listener] xpcall [%s:%s] failed: %s", listener:source(), func_name, result[2])
            result[2] = sformat("event %s execute failed!", event)
        end
        return result
    end
    if not self._ignores[event] then
        self._ignores[event] = true
        log_warn("[Listener][notify_listener] event (%s-%s) handler is nil! ", event, {...})
    end
    return tpack(false, "event handler is nil")
end

function Listener:notify_command(cmd, ...)
    --执行事件
    local listener_map = self._commands[cmd] or {}
    for listener, func_name in pairs(listener_map) do
        local callback_func = listener[func_name]
        local result = tpack(xpcall(callback_func, dtraceback, listener, ...))
        if not result[1] then
            log_fatal("[Listener][notify_command] xpcall [%s:%s] failed: %s!", listener:source(), func_name, result[2])
            result[2] = sformat("cmd %s execute failed!", cmd)
        end
        return result
    end
    if not self._ignores[cmd] then
        log_warn("[Listener][notify_command] command %s handler is nil!", cmd)
        self._ignores[cmd] = true
    end
    return tpack(false, "command handler is nil")
end

return Listener
