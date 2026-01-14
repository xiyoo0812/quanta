--listener.lua
local tpack         = table.pack
local terase        = table.erase
local tinsert       = table.insert
local tremove       = table.remove
local qtweak        = qtable.weak
local log_warn      = logger.warn
local log_fatal     = logger.fatal
local sformat       = string.format
local make_functer  = quanta.make_functer

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
    local functor = make_functer(func_name, 0)
    if not triggers then
        self._triggers[event] = { qtweak({ [functor] = trigger })}
        return
    end
    tinsert(triggers, qtweak({ [functor] = trigger }))
end

function Listener:remove_trigger(trigger, event)
    if event then
        local triggers = self._triggers[event] or {}
        terase(triggers, trigger)
        return
    end
    for _, triggers in ipairs(self._triggers) do
        terase(triggers, trigger)
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
    local functor = make_functer(func_name, 0)
    self._listeners[event] = qtweak({ [functor] = listener })
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
    local functor = make_functer(func_name, 0)
    self._commands[cmd] = qtweak({ [functor] = listener })
end

function Listener:remove_cmd_listener(cmd)
    self._commands[cmd] = nil
end

function Listener:notify_trigger(event, ...)
    local removes = {}
    local triggers = self._triggers[event] or {}
    for i, info in ipairs(triggers) do
        local functor, trigger = next(info)
        if functor then
            local ok, ret = functor:run(trigger, ...)
            if not ok then
                log_fatal("[Listener][notify_trigger] xpcall [{}:{}] failed: {}!", trigger:source(), functor.name, ret)
            end
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

function Listener:notify_listener(event, ...)
    local listener_map = self._listeners[event] or self._listeners["*"] or {}
    for functor, listener in pairs(listener_map) do
        local result = tpack(functor:run(listener, ...))
        if not result[1] then
            log_fatal("[Listener][notify_listener] xpcall [{}:{}] failed: {}", listener:source(), functor.name, result[2])
            result[2] = sformat("event %s execute failed!", event)
        end
        return result
    end
    if not self._ignores[event] then
        self._ignores[event] = true
        log_warn("[Listener][notify_listener] event ({}) handler is nil!", event)
    end
    return tpack(false, "event handler is nil")
end

function Listener:notify_command(cmd, ...)
    --执行事件
    local listener_map = self._commands[cmd] or self._commands["*"] or {}
    for functor, listener in pairs(listener_map) do
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
