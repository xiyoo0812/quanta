--sub_component.lua

local xpcall        = xpcall
local log_warn      = logger.warn
local tunpack       = table.unpack
local dtraceback    = debug.traceback

local SubComponent = mixin()
local prop = property(SubComponent)
prop:reader("subscribers", {})
prop:reader("subhandlers", {})

function SubComponent:__init()
    self:add_trigger(self, "on_subscriber")
    self:add_trigger(self, "on_unsubscriber")
end

--注册订阅器执行函数
function SubComponent:register_subhandler(trigger, event, handler)
    local func_name = handler or event
    local callback_func = trigger[func_name]
    if not callback_func or type(callback_func) ~= "function" then
        log_warn("[SubComponent][register_subhandler] event(%s) handler is nil!", event)
        return
    end
    self.subhandlers[event] = { trigger, func_name }
end

--添加跨服订阅器
function SubComponent:subscriber(serv_name, guid, event, ...)
    self:fire_reliable(serv_name, "on_subscriber", event, guid, ...)
end

--删除跨服订阅器
function SubComponent:unsubscriber(serv_name, event, guid)
    self:fire_reliable(serv_name, "on_unsubscriber", event, guid)
end

--处理添加跨服订阅
function SubComponent:on_subscriber(event, guid, ...)
    if not self.subscribers[event] then
        self.subscribers[event] = {}
    end
    self.subscribers[event][guid] = { ... }
end

--处理删除跨服订阅
function SubComponent:on_unsubscriber(event, guid)
    local subscriber = self.subscribers[event]
    if subscriber then
        subscriber[guid] = nil
    end
end

--发布lobby事件
function SubComponent:pub_lobby_event(event, ...)
    self:pub_event("lobby", event, ...)
end

--发布跨服事件
function SubComponent:pub_event(serv_name, event, ...)
    local subscriber = self.subscribers[event]
    if not subscriber then
        return
    end
    local hand_info = self.subhandlers[event]
    if not hand_info then
        log_warn("[SubComponent][pub_event] event(%s) subhandlers is nil!", event)
        return
    end
    local taigger, func_name = tunpack(hand_info)
    for _, args in pairs(subscriber) do
        local ok, success, res = xpcall(taigger[func_name], dtraceback, taigger, args, ...)
        if not ok then
            log_warn("[SubComponent][notify_event] xpcall [%s:%s] failed: %s!", taigger:source(), func_name, success)
        end
        if success then
            if res then
                self:fire_reliable(serv_name, event, res)
            else
                self:fire_reliable(serv_name, event, ...)
            end
            return
        end
    end
end

return SubComponent
