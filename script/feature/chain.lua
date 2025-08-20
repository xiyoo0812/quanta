--chain.lua
--调用链
local log_err       = logger.err
local jencode       = json.encode
local tinsert       = table.insert
local new_guid      = codec.guid_new
local guid_time     = codec.guid_time
local guid_totrace  = codec.guid_totrace
local pb_encode     = protobuf.encode

local SERV_ID       = quanta.service
local SERV_IDX      = quanta.index

local CHAIN_INFOS   = quanta.get("CHAIN_INFOS")
local CHAIN_PB_URL  = environ.get("QUANTA_CHAIN_PB_URL")
local CHAIN_JS_URL  = environ.get("QUANTA_CHAIN_JSON_URL")

local http_client   = quanta.http_client()

local log_dump      = logfeature.dump("spans", true)

local Chain = class()
local prop = property(Chain)
prop:reader("id", nil)          --id
prop:reader("hex", nil)         --hex
prop:reader("bin", nil)         --bin
prop:reader("time", nil)        --time
prop:reader("span_id", nil)     --span_id
prop:reader("spans", {})        --spans
prop:accessor("co", nil)        --co

function Chain:__init(span_id, chain_id)
    self.id = chain_id or new_guid(SERV_ID, SERV_IDX)
    self.hex, self.bin = guid_totrace(self.id)
    self.time = guid_time(self.id)
    self.span_id = span_id
end

function Chain:push(span)
    tinsert(self.spans, span:context(CHAIN_PB_URL))
    if self.span_id == 0 then
        self:output()
        self.spans = {}
    end
end

function Chain:output()
    CHAIN_INFOS[self.co] = nil
    if next(self.spans) then
        if CHAIN_PB_URL then
            local data = pb_encode("zipkin.spans", { spans = self.spans })
            local ok, status, res = http_client:call_post(CHAIN_PB_URL, data, { ["Content-Type"] = "application/x-protobuf" })
            if not ok or status >= 300 then
                log_err("[Chain][output] opentrace json output field: {}:{}", status, res)
            end
        elseif CHAIN_JS_URL then
            local ok, status, res = http_client:call_post(CHAIN_JS_URL, self.spans, { ["Content-Type"] = "application/json" })
            if not ok or status >= 300 then
                log_err("[Chain][output] opentrace json output field: {}:{}", status, res)
            end
        else
            log_dump("{}", jencode(self.spans))
        end
    end
end

return Chain