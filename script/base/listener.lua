--_listener.lua
local pairs     = pairs
local pcall     = pcall
local xpcall    = xpcall
local tpack     = table.pack
local tunpack   = table.unpack
local log_err   = logger.err

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
    self._triggers[event][trigger] = true
end

function Listener:remove_trigger(trigger, event)
    if self._triggers[event] then
        self._triggers[event][trigger] = nil
    end
end

function Listener:add_listener(listener, event)
    if self._listeners[event] then
        log_err("add_listener event(%s) repeat!", event)
        return
    end
    self._listeners[event] = listener
end

function Listener:remove_listener(event)
    self._listeners[event] = nil
end

function Listener:add_cmd_listener(listener, cmd, event)
    if self._commands[cmd] then
        log_err("add_cmd_listener cmd(%s) repeat!", cmd)
        return
    end
    self._commands[cmd] = {listener, event}
end

function Listener:remove_cmd_listener(cmd)
    self._commands[cmd] = nil
end

function Listener:notify_trigger(event, ...)
    for trigger in pairs(self._triggers[event] or {}) do
        if trigger[event] then
            local ok, ret = xpcall(trigger[event], debug.traceback, trigger, ...)
            if not ok then
                log_err("notifytrigger xpcall %s:%s failed, err : %s!", trigger, event, ret)
            end
        end
    end
end

function Listener:notify_listener(event, ...)
    local listener = self._listeners[event]
    if not listener or not listener[event] then
        return tpack(false, "event handler is nil")
    end
    local result = tpack(pcall(listener[event], listener, ...))
    if not result[1] then
        log_err("notify_listener event(%s) failed, because: %s!", event, result[2])
    end
    return result
end

function Listener:notify_command(cmd, ...)
    local context = self._commands[cmd]
    if not context then
        return tpack(false, "event handler is nil")
    end
    local listener, event = tunpack(context)
    if not listener or not listener[event] then
        return tpack(false, "event handler is nil")
    end
    local result = tpack(pcall(listener[event], listener, ...))
    if not result[1] then
        log_err("notify_command event(%s) failed, because: %s!", event, result[2])
    end
    return result
end

return Listener
