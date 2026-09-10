--node_http.lua
local log_warn      = logger.warn
local log_debug     = logger.debug

local event_mgr     = quanta.get("event_mgr")
local http_client   = quanta.get("http_client")

local NodeBase = import("robot/nodes/node_base.lua")

local NodeHttp = class(NodeBase)
local prop = property(NodeHttp)
prop:reader("url", nil)     --url
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

function NodeHttp:on_action()
    if self.url then
        if self.method == "GET" then
            self.querys = self:read_inputs(self.inputs)
        else
            self.body = self:read_inputs(self.inputs)
        end
        local role = self.actor
        local ok, status, res = http_client:send_request(self.url, self.timeout, self.querys, self.headers, self.method, self.body)
        if not ok or status >= 300 then
            log_warn("[NodeHttp][on_action] robot:{} call {} failed: status={}, res={}", role.open_id, self.url, status, res)
            event_mgr:notify_trigger("on_error_message", self.url, role.open_id, res)
            self:failed(res)
            return false
        end
        log_debug("[NodeHttp][on_action] robot:{} call {}=>{} success", role.open_id, self.url, res)
        self:write_outputs(self.outputs, res)
    end
    return true
end

return NodeHttp
