--node_http.lua
local log_warn      = logger.warn
local log_debug     = logger.debug

local event_mgr     = quanta.get("event_mgr")
local http_client   = quanta.get("http_client")

local NodeBase = import("robot/nodes/node_base.lua")

local NodeHttp = class(NodeBase)
local prop = property(NodeHttp)
prop:reader("url", nil)     --url
prop:reader("result", nil)  --result
prop:reader("method", nil)  --method
prop:reader("timeout", nil) --timeout
prop:reader("headers", {})  --headers

function NodeHttp:__init(case)
end

function NodeHttp:on_load(conf)
    self.url = conf.url
    self.method = conf.method
    self.headers = conf.headers
    self.outputs = conf.outputs
    self.timeout = conf.timeout or 5000
    return true
end

function NodeHttp:on_start()
    if self.url then
        local role = self.actor
        local values, err = self:read_inputs(self.inputs)
        if not values then
            log_warn("[NodeHttp][on_start] robot:{}  call {} collect inputs {} failed!", role.open_id, self.url, self.inputs)
            self:failed(err)
            return
        end
        if self.method == "GET" then
            self.querys = values
        else
            self.body = values
        end
        local ok, status, res = http_client:send_request(self.url, self.timeout, self.querys, self.headers, self.method, self.body)
        if not ok or status >= 300 then
            log_warn("[NodeHttp][on_start] robot:{} call {} failed: status={}, res={}", role.open_id, self.url, status, res)
            event_mgr:notify_trigger("on_error_message", self.url, role.open_id, res)
            self:failed(res)
            return
        end
        log_debug("[NodeHttp][on_start] robot:{} call {}=>{} success", role.open_id, self.url, res)
        self:write_outputs(self.outputs, res)
    end
end

return NodeHttp
