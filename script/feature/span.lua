--span.lua

local lnow_ms       = timer.now_ms
local log_debug     = logger.debug
local jencode       = json.encode
local lrandomkey    = crypt.randomkey

local SERVICE_NAME  = quanta.name
local SERVICE_HOST  = quanta.host

local LOG_PATH      = environ.get("QUANTA_LOG_PATH", "./logs/")
local log_dump      = logfeature.dump("spans", LOG_PATH .. "../spans/", true)

local Span = class()
local prop = property(Span)
prop:reader("id", nil)     --id
prop:reader("name", nil)        --name
prop:reader("trace_id", nil)    --trace_id
prop:reader("parent_id", nil)   --parent_id
prop:reader("timestamp", nil)   --timestamp
prop:reader("annotations", {})  --annotations
prop:reader("tags", {})         --tags

function Span:__init(name, trace_id, parent_id)
    self.name = name
    self.id = lrandomkey(1)
    self.trace_id = trace_id or lrandomkey(1)
    self.timestamp = lnow_ms() * 1000
    self.parent_id = parent_id
end

--https://zipkin.io/zipkin-api/
function Span:__defer()
    local arsg = {{
        id = self.id,
        kind = "CLIENT",
        tags = self.tags,
        name = self.name,
        traceId = self.trace_id,
        parentId = self.parent_id,
        timestamp = self.timestamp,
        annotations = self.annotations,
        duration = lnow_ms() * 1000 - self.timestamp,
        localEndpoint = {
            serviceName = SERVICE_NAME,
            ipv4 = SERVICE_HOST
        }
    }}
    log_dump(jencode(arsg))
end

function Span:track(annotation, tags)
    self:set_tags(tags)
    self:add_annotation(annotation)
    log_debug("{}: tags = {}", annotation, tags)
end

function Span:set_tag(tag, value)
    self.param.tags[tag] = tostring(value)
end

function Span:set_tags(tags)
    for tag, value in pairs(tags or {}) do
        self.param.tags[tag] = tostring(value)
    end
end

function Span:add_annotation(value)
    local annotations = self.param.annotations
    annotations[#annotations + 1] = {
        value = tostring(value),
        timestamp = lnow_ms() * 1000
    }
end

return Span
