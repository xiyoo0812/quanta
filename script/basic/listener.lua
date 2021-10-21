--_listener.lua
local pcall     = pcall
local xpcall    = xpcall
local ipairs    = ipairs
local tpack     = table.pack
local tinsert   = table.insert
local tunpack   = table.unpack
local tremove   = table.remove
local log_err   = logger.err
local log_warn  = logger.warn
local dtraceback= debug.traceback

local Listener = class()
function Listener:__init()
    self._triggers = {}     -- map<event, {listener = callback, ...}
    self._listeners = {}    -- map<event, listener>
    self._commands = {}     -- map<cmd, listener>
end

function Listener:add_trigger(trigger, event, handler)
    if not self._triggers[event] then
        self._triggers[event] = {}
    end
    local handler_func = trigger[event]
    if handler then
        handler_func = trigger[handler]
    end
    if not handler_func or type(handler_func) ~= "function" then
        log_warn("[Listener][add_trigger] event(%s) handler is nil!", event)
        return
    end
    tinsert(self._triggers[event], { trigger, handler_func })
end

function Listener:remove_trigger(trigger, event)
    local trigger_array = self._triggers[event]
    if trigger_array then
        for i, context in pairs(trigger_array or {}) do
            if context[1] == trigger then
                tremove(trigger_array, i)
            end
        end
    end
end

function Listener:add_listener(listener, event, handler)
    if self._listeners[event] then
        log_warn("[Listener][add_listener] event(%s) repeat!", event)
        return
    end
    local handler_func = listener[event]
    if handler then
        handler_func = listener[handler]
    end
    if not handler_func or type(handler_func) ~= "function" then
        log_warn("[Listener][add_listener] event(%s) callback is nil!", event)
        return
    end
    self._listeners[event] = { listener, handler_func }
end

function Listener:remove_listener(event)
    self._listeners[event] = nil
end

function Listener:add_cmd_listener(listener, cmd, event)
    if self._commands[cmd] then
        log_warn("[Listener][add_cmd_listener] cmd(%s) repeat!", cmd)
        return
    end
    local handler_func = listener[event]
    if not handler_func or type(handler_func) ~= "function" then
        log_warn("[Listener][add_cmd_listener] event(%s) handler is nil!", event)
        return
    end
    self._commands[cmd] = { listener, handler_func }
end

function Listener:remove_cmd_listener(cmd)
    self._commands[cmd] = nil
end

function Listener:notify_trigger(event, ...)
    for _, trigger_ctx in ipairs(self._triggers[event] or {}) do
        local trigger, handler = tunpack(trigger_ctx)
        local ok, ret = xpcall(handler, dtraceback, trigger, ...)
        if not ok then
            log_err("[Listener][notify_listener] xpcall %s:%s failed, err : %s!", trigger, event, ret)
        end
    end
end

function Listener:notify_listener(event, ...)
    local listener_ctx = self._listeners[event]
    if not listener_ctx then
        log_warn("[Listener][notify_listener] event %s handler is nil!", event)
        return tpack(false, "event handler is nil")
    end
    local listener, handler = tunpack(listener_ctx)
    local result = tpack(pcall(handler, listener, ...))
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
    local listener, handler = tunpack(listener_ctx)
    local result = tpack(pcall(handler, listener, ...))
    if not result[1] then
        log_err("[Listener][notify_command] notify cmd(%s) failed, because: %s!, traceback:%s!", cmd, result[2], dtraceback())
    end
    return result
end

--创建全局监听器
quanta.event_mgr = Listener()

return Listener
