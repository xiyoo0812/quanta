--trace_test.lua
local log_debug     = logger.debug
local qtraceing     = quanta.traceing

local timer_mgr     = quanta.get("timer_mgr")
local event_mgr     = quanta.get("event_mgr")
local router_mgr    = quanta.get("router_mgr")

local function trace_func4()
    local key4 = 44
    log_debug("[trace_test][trace_func4] call trace_func4")
    local span<close> = qtraceing("trace_func3")
    span:add_annotation("call trace_func4!")
    span:add_tag("key4", key4)
end

local function trace_func3()
    local key3 = 33
    log_debug("[trace_test][trace_func3] call trace_func3")
    local span<close> = qtraceing("trace_func3")
    span:add_annotation("call trace_func3!")
    span:add_tag("key3", key3)
    trace_func4()
end

local function trace_func2()
    local key2 = 22
    log_debug("[trace_test][trace_func2] call trace_func2")
    local span<close> = qtraceing("trace_func2")
    span:add_annotation("call trace_func2!")
    span:add_tag("key2", key2)
    local target = service.make_sid(service.name2sid("test"), 2)
    local ok, res =  router_mgr:call_target(target, "rpc_trace_test")
    if ok and res then
        local fspan = qtraceing("trace2_finish")
        fspan:add_annotation("call trace finish!")
        fspan:add_tag("key5", "5555")
    end
end

local function trace_func1()
    local key1 = 11
    local span<close> = qtraceing("trace_func1")
    log_debug("[trace_test][trace_func1] call trace_func1")
    span:add_annotation("call trace_func1!")
    span:add_tag("key1", key1)
    trace_func2()
end

local time = quanta.index == 1 and 2000 or 0
timer_mgr:once(time, function()
    if quanta.index == 1 then
        trace_func1()
    else
        quanta.testobj = {
            ["rpc_trace_test"] = function(self)
                trace_func3()
                return true
            end
        }
        event_mgr:add_listener(quanta.testobj, "rpc_trace_test")
    end
end)

