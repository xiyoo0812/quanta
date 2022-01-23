--zipkin.lua
import("network/http_client.lua")
local lcrypt        = require("lcrypt")

local log_err       = logger.err
local log_info      = logger.info
local tinsert       = table.insert
local sformat       = string.format
local new_guid      = lcrypt.guid_new

local http_client   = quanta.get("http_client")

local Zipkin = singleton()
local prop = property(Zipkin)
prop:reader("addr", nil)        --http addr
prop:reader("host", nil)        --host
prop:reader("enable", false)    --enable
prop:reader("spans", {})        --spans
prop:reader("span_indexs", {})  --span_indexs

function Zipkin:__init()
end

function Zipkin:setup()
    local ip, port =  environ.addr("QUANTA_OTRACE_ADDR")
    if ip and port then
        self.enable = true
        self.host = environ.get("QUANTA_HOST_IP")
        self.addr = sformat("http://%s:%s/api/v2/spans", ip, port)
        log_info("[Zipkin][setup] setup (%s) success!", self.addr)
    end
end

--https://zipkin.io/zipkin-api/
function Zipkin:general(name, trace_id, parent_id)
    local span_id = new_guid()
    local span = {
        tags = {},
        name = name,
        id = span_id,
        kind = "CLIENT",
        traceId = trace_id,
        parentId = parent_id,
        timestamp = quanta.now_ms * 1000,
        annotations = {},
        localEndpoint = {
            serviceName = quanta.name,
            ipv4 = self.host
        }
    }
    self.span_indexs[span_id] = trace_id
    if not self.spans[trace_id] then
        self.spans[trace_id] = { }
    end
    tinsert(self.spans[trace_id], span)
    log_info("[Zipkin][general] new span name:%s, id:%s, trace_id:%s, parent_id:%s!", name, span_id, trace_id, parent_id)
    return span
end

function Zipkin:new_span(name)
    local trace_id = new_guid()
    return self:general(name, trace_id)
end

function Zipkin:sub_span(name, parent_id)
    if not parent_id then
        return self:new_span(name)
    end
    local parent = self.span_indexs[parent_id]
    if not parent then
        return self:new_span(name)
    end
    return self:new_span(name, parent.traceId, parent_id)
end

function Zipkin:set_tag(span, tag, value)
    span.tags[tag] = value
    span.duration = quanta.now_ms * 1000 - span.timestamp
end

function Zipkin:set_annotation(span, value)
    local annotation = {
        value = value,
        timestamp = quanta.now_ms * 1000
    }
    tinsert(span.annotations, annotation)
    span.duration = quanta.now_ms * 1000 - span.timestamp
end

function Zipkin:recovery_span(span)
    span.share = true
    self.span_indexs[span.id] = span.traceId
    self.spans[span.traceId] = { span }
    return span
end

function Zipkin:inject_span(span)
    return {
        id = span.id,
        name = span.name,
        traceId = span.traceId,
        parentId = span.parentId
    }
end

function Zipkin:finish_span(span)
    if self.enable then
        local span_list = self.spans[span.traceId]
        for span_id in pairs(span_list) do
            self.span_indexs[span_id] = nil
        end
        local ok, status, res = http_client:call_post(self.addr, span_list)
        if not ok then
            log_err("[Zipkin][finish_span] post failed! code: %s, err: %s", status, res)
        end
        self.spans[span.traceId] = nil
    end
end

quanta.zipkin = Zipkin()

return Zipkin
