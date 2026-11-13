--listener.lua
local terase        = table.erase
local tinsert       = table.insert
local tremove       = table.remove
local qtweak        = qtable.weak
local log_warn      = logger.warn
local make_functer  = quanta.make_functer

local FAILED        = quanta.enum("KernCode", "FAILED")

local Listener = class()
function Listener:__init()
    self._triggers = {}     -- map<event, {{[functor] = trigger}, ...}
    self._listeners = {}    -- map<event, {[functor] = listener}
    self._messages = {}     -- map<cmd, {[functor] = listener}
    self._ignores = {}      -- map<cmd, bool>
end

function Listener:listen_trigger(trigger, event, handler)
    local func_name = handler or event
    local callback_func = trigger[func_name]
    if not callback_func or type(callback_func) ~= "function" then
        log_warn("[Listener][listen_trigger] event({}) handler not define", event)
        return
    end
    local triggers = self._triggers[event]
    local functor = make_functer(func_name, 0)
    if not triggers then
        self._triggers[event] = { qtweak({ [functor] = trigger })}
        return
    end
    tinsert(triggers, qtweak({ [functor] = trigger }))
end

function Listener:unlisten_trigger(trigger, event)
    if event then
        local triggers = self._triggers[event] or {}
        terase(triggers, trigger)
        return
    end
    for _, triggers in ipairs(self._triggers) do
        terase(triggers, trigger)
    end
end

function Listener:listen_event(listener, event, handler)
    if self._listeners[event] then
        log_warn("[Listener][listen_event] event({}) will be replace!", event)
    end
    local func_name = handler or event
    local callback_func = listener[func_name]
    if not callback_func or type(callback_func) ~= "function" then
        log_warn("[Listener][listen_event] event({}) callback not define!", event)
        return
    end
    local functor = make_functer(func_name, 0)
    self._listeners[event] = qtweak({ [functor] = listener })
end

function Listener:unlisten_event(event)
    self._listeners[event] = nil
end

function Listener:listen_message(listener, pb_cmd, handler)
    if self._messages[pb_cmd] then
        log_warn("[Listener][listen_message] pb_cmd({}) repeat!", pb_cmd)
        return
    end
    local func_name = handler
    local callback_func = listener[func_name]
    if not callback_func or type(callback_func) ~= "function" then
        log_warn("[Listener][listen_message] pb_cmd({}) handler not define!", pb_cmd)
        return
    end
    local functor = make_functer(func_name, 0)
    self._messages[pb_cmd] = qtweak({ [functor] = listener })
end

function Listener:unlisten_message(pb_cmd)
    self._messages[pb_cmd] = nil
end

function Listener:notify_trigger(event, ...)
    local removes = {}
    local triggers = self._triggers[event] or {}
    for i, info in ipairs(triggers) do
        local functor, trigger = next(info)
        if functor then
            functor:call(trigger, ...)
        else
            tinsert(removes, i)
        end
    end
    if #removes > 0 then
        for i = #triggers, 1, -1 do
            tremove(triggers, i)
        end
    end
end

function Listener:notify_event(event, ...)
    local listener_map = self._listeners[event] or {}
    for functor, listener in pairs(listener_map) do
        return true, functor:call(listener, ...)
    end
    if not self._ignores[event] then
        self._ignores[event] = true
        log_warn("[Listener][notify_event] event ({}) handler is nil!", event)
    end
    return false, FAILED, "event handler is nil"
end

function Listener:notify_message(message, ...)
    --执行事件
    local cmd_id = message.cmd_id
    local listener_map = self._messages[cmd_id] or {}
    for functor, listener in pairs(listener_map) do
        functor:call(listener, message, message.request, message.response, ...)
        return true
    end
    if not self._ignores[cmd_id] then
        log_warn("[Listener][notify_message] command {} handler is nil!", cmd_id)
        self._ignores[cmd_id] = true
    end
    return false
end

return Listener
