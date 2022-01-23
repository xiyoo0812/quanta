--zipkin.lua
import("network/http_client.lua")
local ljson         = require("lcjson")

local log_err       = logger.err
local sformat       = string.format
local saddr         = string_ext.addr

local http_client   = quanta.get("http_client")

local Zipkin = class()
local prop = property(Zipkin)
prop:reader("addr", nil)        --http addr
prop:reader("host", nil)        --host

function Zipkin:__init()
end

function Zipkin:setup()
    local ip, port =  environ.addr("QUANTA_OTRACE_ADDR")
    if ip and port then
        self.host = environ.get("QUANTA_HOST_IP")
        self.addr = sformat("http://%s:%s/api/v2/spans", ip, port)
        log_info("[Zipkin][setup] setup http (%s) success!", self.addr)
    end
end

function Zipkin:flush(spans)
    if self.addr then
        local ok, status, res = http_client:call_post(self.addr, spans)
        if not ok then
            log_err("[Zipkin][flush] http failed! code: %s, err: %s", status, res)
        end
    end
end

return Zipkin
