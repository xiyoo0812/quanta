--span.lua

local mrandom       = qmath.random
local lnow_cs       = timer.now_cs
local sformat       = string.format
local guid_tohex    = codec.guid_tohex

local KIND          = sformat("thread<%s:%s>", quanta.thread,  quanta.tid)
local END_POINT     = { serviceName = sformat("%s<pid:%s>", quanta.name, quanta.pid), ipv4 = luabus.host() }

local Span = class()
local prop = property(Span)
prop:reader("id", nil)          --id
prop:reader("name", nil)        --name
prop:reader("trace", nil)       --trace
prop:reader("parent_id", nil)   --parent_id
prop:reader("timestamp", nil)   --timestamp
prop:reader("annotations", {})  --annotations
prop:reader("tags", {})         --tags

function Span:__init(name, trace)
    self.name = name
    self.trace = trace
    self.id = mrandom()
    self.timestamp = lnow_cs()
    self.parent_id = trace.span_id
    trace.span_id = self.id
end

--https://zipkin.io/zipkin-api/
function Span:__defer()
    local arsg = {
        kind = KIND,
        tags = self.tags,
        name = self.name,
        traceId = self.trace.hex,
        shared = self.trace.shared,
        timestamp = self.timestamp,
        annotations = self.annotations,
        duration = lnow_cs() - self.timestamp,
        parentId = self:format_span_id(self.parent_id),
        id = self:format_span_id(self.id),
        localEndpoint = END_POINT
    }
    self.trace.span_id = self.parent_id
    self.trace:push(arsg)
end

function Span:format_span_id(span_id)
    if span_id ~= 0 then
        return guid_tohex(span_id << 32 | self.trace.time)
    end
end

function Span:trace(tags, annotation)
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
