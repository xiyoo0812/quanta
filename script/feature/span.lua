--span.lua

local mrandom       = qmath.random
local lnow_cs       = timer.now_cs
local sformat       = string.format
local guid_tobin    = codec.guid_tobin
local guid_tohex    = codec.guid_tohex

local HOST, BHOST   = luabus.host()
local KIND_PB       = protobuf.enum("zipkin.Kind", "CLIENT")
local KIND_JS       = protobuf.enum("zipkin.Kind", KIND_PB)
local SERVICE_NAME  = sformat("%s<%s>[%s.%s]", quanta.name, quanta.pid, quanta.thread, quanta.tid)
local ENDPOINT_JS   = { serviceName = SERVICE_NAME, ipv4 = HOST }
local ENDPOINT_PB   = { service_name = SERVICE_NAME, ipv4 = BHOST }

local Span = class()
local prop = property(Span)
prop:reader("id", nil)          --id
prop:reader("name", nil)        --name
prop:reader("chain", nil)       --chain
prop:reader("parent_id", nil)   --parent_id
prop:reader("timestamp", nil)   --timestamp
prop:reader("annotations", {})  --annotations
prop:reader("tags", {})         --tags

function Span:__init(name, chain)
    self.name = name
    self.chain = chain
    self.id = mrandom()
    self.timestamp = lnow_cs()
    self.parent_id = chain.span_id
    chain.span_id = self.id
end

--https://zipkin.io/zipkin-api/
function Span:__defer()
    self.chain.span_id = self.parent_id
    self.chain:push(self)
end

function Span:context(pb)
    if pb then
        return {
            kind = KIND_PB,
            tags = self.tags,
            name = self.name,
            trace_id = self.chain.bin,
            timestamp = self.timestamp,
            annotations = self.annotations,
            duration = lnow_cs() - self.timestamp,
            parent_id = self:span_id(self.parent_id, guid_tobin),
            id = self:span_id(self.id, guid_tobin),
            local_endpoint = ENDPOINT_PB
        }
    end
    return {
        kind = KIND_JS,
        tags = self.tags,
        name = self.name,
        traceId = self.chain.hex,
        timestamp = self.timestamp,
        annotations = self.annotations,
        duration = lnow_cs() - self.timestamp,
        parent_id = self:span_id(self.parent_id, guid_tohex),
        id = self:span_id(self.id, guid_tohex),
        localEndpoint = ENDPOINT_JS
    }
end

function Span:span_id(span_id, func)
    if span_id ~= 0 then
        return func(span_id << 32 | self.chain.time)
    end
end

function Span:chain(tags, annotation)
    self:add_tags(tags)
    self:add_annotation(annotation)
end

function Span:add_tags(tags)
    for tag, value in pairs(tags or {}) do
        self.tags[tag] = tostring(value)
    end
end

function Span:add_tag(tag, value)
    self.tags[tag] = tostring(value)
end

function Span:add_annotation(value)
    local annotations = self.annotations
    annotations[#annotations + 1] = {
        value = tostring(value),
        timestamp = lnow_cs()
    }
end

return Span
