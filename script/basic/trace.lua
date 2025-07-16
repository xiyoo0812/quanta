--trace.lua
local mrandom       = qmath.random
local co_running    = coroutine.running

local CHAIN_INFOS   = quanta.init("CHAIN_INFOS")

local function new_chain(span_id, trace_id)
    local Chain = import("feature/chain.lua")
    return Chain(span_id, trace_id)
end

function quanta.new_trace()
    local Chain = import("feature/chain.lua")
    return Chain(mrandom())
end

function quanta.bind_trace(chain, co)
    if chain then
        CHAIN_INFOS[co] = chain
        chain:set_co(co)
    end
end

function quanta.traceing(name)
    local co = co_running()
    local chain = CHAIN_INFOS[co]
    if not chain then
        chain = new_chain(0)
        CHAIN_INFOS[co] = chain
        chain:set_co(co)
    end
    local Span = import("feature/span.lua")
    return Span(name, chain)
end

function quanta.extract_trace()
    local chain = CHAIN_INFOS[co_running()]
    if chain then
        return chain.id, chain.span_id
    end
    return 0, 0
end

function quanta.resume_trace(trace_id, span_id)
    if trace_id > 0 then
        return new_chain(span_id, trace_id)
    end
end

function quanta.trace_id()
    local chain = CHAIN_INFOS[co_running()]
    if chain then
        return chain.hex
    end
end
