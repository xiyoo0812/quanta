--chain.lua
--调用链
local jencode       = json.encode
local tinsert       = table.insert
local new_guid      = codec.guid_new
local guid_time     = codec.guid_time
local guid_tohex    = codec.guid_tohex
local log_err       = logger.err

local SERV_ID       = quanta.service
local SERV_IDX      = quanta.index

local CHAIN_INFOS   = quanta.get("CHAIN_INFOS")
local CHAIN_URL     = environ.get("QUANTA_CHAIN_URL")

local http_client   = quanta.get("http_client")
local log_dump      = logfeature.dump("spans", true)

local Chain = class()
local prop = property(Chain)
prop:reader("id", nil)          --id
prop:reader("hex", nil)         --hex
prop:reader("time", nil)        --time
prop:reader("span_id", nil)     --span_id
prop:reader("spans", {})        --spans
prop:accessor("co", nil)        --co
prop:accessor("shared", nil)    --shared

function Chain:__init(span_id, chain_id)
    self.id = chain_id or new_guid(SERV_ID, SERV_IDX)
    self.hex = guid_tohex(self.id)
    self.time = guid_time(self.id)
    self.span_id = span_id
end

function Chain:push(span)
    tinsert(self.spans, span)
    if self.span_id == 0 then
        self:output()
        self.spans = {}
    end
end

function Chain:output()
    CHAIN_INFOS[self.co] = nil
    if next(self.spans) then
        local span_data = jencode(self.spans)
        log_dump("{}", span_data)
        if CHAIN_URL then
            local ok, status = http_client:call_post(CHAIN_URL, span_data, { ["Content-Type"] = "application/json" })
            if not ok or status > 202 then
                log_err("[Chain][output] opentrace output field: {}", status)
            end
        end
    end
end

return Chain