-- track.lua
local sformat       = string.format
local co_running    = coroutine.running

local TRACE_SPANS   = quanta.init("TRACE_SPANS")

local function build_span(name, ispan)
    local co = co_running()
    local Span = import("feature/span.lua")
    local span = Span(name, ispan.trace_id, ispan.parent_id)
    RACE_SPANS[co] = span
    return span
end

function quanta.new_span(name, ispan)
    return build_span(name, ispan.trace_id, ispan.parent_id)
end

function quanta.tracking(name, tags)
    local co = co_running()
    local span = TRACE_SPANS[co]
    if not span then
        span = build_span(name)
        TRACE_SPANS[co] = span
    end
    span:track(name, tags)
    return span
end

function quanta.inject_span()
    local span = TRACE_SPANS[co_running()]
    if span then
        return { span.trace_id, span.id }
    end
end

function quanta.track_id()
    local span = TRACE_SPANS[co_running()]
    if not span then
        return ""
    end
    return sformat(" T-%d", span.trace_id)
end

function quanta.pass_span(co)
    local span = TRACE_SPANS[co_running()]
    if span then
        TRACE_SPANS[co] = span
    end
end

function quanta.tracked(co)
    TRACE_SPANS[co] = nil
end
