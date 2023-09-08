-- ws_test.lua

local WSServer = import("network/ws_server.lua")
local server = WSServer("0.0.0.0:8001")
quanta.server = server
