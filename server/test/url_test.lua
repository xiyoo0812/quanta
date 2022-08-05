-- url_test.lua
local ljson = require("lcjson")
local lhttp = require("lhttp")

local log_debug     = logger.debug
local json_encode   = ljson.encode

local text = "GET /uri.cgi?aaa=ds HTTP/1.1\r\nUser-Agent: Mozilla/5.0\r\nHost: 127.0.0.1\r\n\r\n{'AAA':123}"

local function dump_req(name, req)
    log_debug("%s: method:%s, url:%s, ver:%s, body:%s", name, req.method, req.url, req.version, req.body)
    log_debug("%s: headers:%s", name, req.get_headers())
    log_debug("%s: params:%s", name, req.get_params())
end

local function dump_req_header(name, req, key)
    log_debug("%s: key:%s, value:%s", name, key, req.get_header(key))
end

local function dump_req_param(name, req, key)
    log_debug("%s: key:%s, param:%s", name, key, req.get_param(key))
end

local req1 = lhttp.create_request()
if req1.parse(text) then
    dump_req("req1", req1)
    dump_req_header("req1", req1, "User-Agent")
    dump_req_header("req1", req1, "Accept")
    dump_req_header("req1", req1, "Host")
    dump_req_param("req1", req1, "aaa")
end

local resp1 = lhttp.create_response()
resp1.set_header("Content-Type", "text/plain")
resp1.content = json_encode({a=2,b=3,c={d=4}})
log_debug("resp : %s", resp1.serialize())
