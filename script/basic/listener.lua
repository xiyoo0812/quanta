--listener.lua
local tpack         = table.pack
local tinsert       = table.insert
local sformat       = string.format
local qtweak        = qtable.weak
local log_warn      = logger.warn
local log_fatal     = logger.fatal
local dtraceback    = debug.traceback
local obj_functer   = quanta.obj_functer

local Listener = class()
function Listener:__init()
    self._triggers = {}     -- map<event, {{[listener] = func_name}, ...}
    self._listeners = {}    -- map<event, {[listener] = func_name}
    self._commands = {}     -- map<cmd, {[listener] = func_name}
    self._ignores = {}      -- map<cmd, bool>
end

function Listener:add_trigger(trigger, event, handler)
    local func_name = handler or event
    local callback_func = trigger[func_name]
    if not callback_func or type(callback_func) ~= "function" then
        log_warn("[Listener][add_trigger] event({}) handler not define", event)
        return
    end
    local triggers = self._triggers[event]
    local functor = obj_functer(trigger, callback_func, 0, func_name)
    if not triggers then
        self._triggers[event] = { qtweak({ [trigger] = functor })}
        return
    end
    tinsert(triggers, qtweak({ [trigger] = functor }))
end

function Listener:remove_trigger(trigger, event)
    if event then
        local triggers = self._triggers[event] or {}
        triggers[trigger] = nil
        return
    end
    for _, triggers in ipairs(self._triggers) do
        triggers[trigger] = nil
    end
end

function Listener:add_listener(listener, event, handler)
    if self._listeners[event] then
        log_warn("[Listener][add_listener] event({}) will be replace!", event)
    end
    local func_name = handler or event
    local callback_func = listener[func_name]
    if not callback_func or type(callback_func) ~= "function" then
        log_warn("[Listener][add_listener] event({}) callback not define!", event)
        return
    end
    local functor = obj_functer(listener, callback_func, 0, func_name)
    self._listeners[event] = qtweak({ [listener] = functor })
end

function Listener:remove_listener(event)
    self._listeners[event] = nil
end

function Listener:add_cmd_listener(listener, cmd, handler)
    if self._commands[cmd] then
        log_warn("[Listener][add_cmd_listener] cmd({}) repeat!", cmd)
        return
    end
    local func_name = handler
    local callback_func = listener[func_name]
    if not callback_func or type(callback_func) ~= "function" then
        log_warn("[Listener][add_cmd_listener] cmd({}) handler not define!", cmd)
        return
    end
    local functor = obj_functer(listener, callback_func, 0, func_name)
    self._commands[cmd] = qtweak({ [listener] = functor })
end

function Listener:remove_cmd_listener(cmd)
    self._commands[cmd] = nil
end

function Listener:notify_trigger(event, ...)
    local triggers = self._triggers[event] or {}
    for _, info in ipairs(triggers) do
        local trigger, functor = next(info)
        local ok, ret = functor:run(trigger, ...)
        if not ok then
            log_fatal("[Listener][notify_trigger] xpcall [{}:{}] failed: {}!", trigger:source(), functor.name, ret)
        end
    end
end

function Listener:notify_listener(event, ...)
    local listener_map = self._listeners[event] or self._listeners["*"] or {}
    for listener, functor in pairs(listener_map) do
        local result = tpack(functor:run(listener, ...))
        if not result[1] then
            log_fatal("[Listener][notify_listener] xpcall [{}:{}] failed: {}", listener:source(), functor.name, result[2])
            result[2] = sformat("event %s execute failed!", event)
        end
        return result
    end
    if not self._ignores[event] then
        self._ignores[event] = true
        log_warn("[Listener][notify_listener] event ({}) handler is nil! {}", event, dtraceback())
    end
    return tpack(false, "event handler is nil")
end

function Listener:notify_command(cmd, ...)
    --执行事件
    local listener_map = self._commands[cmd] or self._commands["*"] or {}
    for listener, functor in pairs(listener_map) do
        local result = tpack(functor:run(listener, ...))
        if not result[1] then
            log_fatal("[Listener][notify_command] xpcall [{}:{}] failed: {}!", listener:source(), functor.name, result[2])
            result[2] = sformat("cmd %s execute failed!", cmd)
        end
        return result
    end
    if not self._ignores[cmd] then
        log_warn("[Listener][notify_command] command {} handler is nil!", cmd)
        self._ignores[cmd] = true
    end
    return tpack(false, "command handler is nil")
end

return Listener
