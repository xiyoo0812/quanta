-- ws_test.lua
local ljson = require("lcjson")
local ltimer = require("ltimer")

local ltime         = ltimer.time
local log_debug     = logger.debug
local json_encode   = ljson.encode

local thread_mgr    = quanta.get("thread_mgr")

local data = { aaa = 123 }
local on_message = function(url, message)
    log_debug("on_message: %s, %s, %s", url, message)
    return data
end
local WSServer = import("network/ws_server.lua")
local server = WSServer("0.0.0.0:8001")
server:register_post("*", on_message)
quanta.server = server
