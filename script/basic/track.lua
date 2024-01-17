-- track.lua
local sformat       = string.format
local co_running    = coroutine.running

local TRACE_SPANS   = quanta.init("TRACE_SPANS")

local function new_span(name, trace_id, parent_id)
   local Span = import("feature/span.lua")
    return Span(name, trace_id, parent_id)
end

function quanta.tracking(name, annotation, tags)
    local co = co_running()
    local span = TRACE_SPANS[co]
    if not span then
        span = new_span(name)
        TRACE_SPANS[co] = span
    end
    if annotation then
        span:track(annotation, tags)
    end
    return span
end

function quanta.inject_span()
    local span = TRACE_SPANS[co_running()]
    if span then
        return span.trace_id, span.id
    end
end

function quanta.track_id()
    local span = TRACE_SPANS[co_running()]
    if not span then
        return ""
    end
    return sformat(" T-%d", span.trace_id)
end

function quanta.tracked(co)
    TRACE_SPANS[co] = nil
end
