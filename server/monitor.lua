#!./quanta
import("kernel.lua")
local ljson         = require("luacjson")

local log_info      = logger.info
local qxpcall       = quanta.xpcall
local quanta_update = quanta.update
local json_encode   = ljson.encode
local json_decode   = ljson.decode

if not quanta.init_flag then
    --初始化quanta
    ljson.encode_sparse_array(true)
    qxpcall(quanta.init, "quanta.init error: %s")

    local NetServer = import("kernel/network/net_server.lua")
    --创建客户端网络管理
    quanta.client_mgr = NetServer("gate_client")
    quanta.client_mgr:setup("QUANTA_MONITOR_ADDR", false)
    --设置编解码器
    quanta.client_mgr:set_encoder(function(cmd_id, data)
        return json_encode(data)
    end)
    quanta.client_mgr:set_decoder(function(cmd_id, data)
        return json_decode(data)
    end)

    import("monitor/monitor_mgr.lua")
    import("monitor/web_mgr.lua")

    log_info("monitor %d now startup!", quanta.id)

    quanta.init_flag = true
end

quanta.run = function()
    qxpcall(quanta_update, "quanta_update error: %s")
end
