--dbsvr.lua
import("kernel.lua")

local log_info      = logger.info
local qxpcall       = quanta.xpcall
local quanta_update = quanta.update
local qxpcall_quit  = quanta.xpcall_quit

quanta.run = function()
    qxpcall(quanta_update, "quanta_update error: %s")
end

if not quanta.init_flag then
    local function startup()
        --初始化quanta
        quanta.init()
        --初始化dbsvr
        import("dbsvr/database_mgr.lua")
        log_info("dbsvr %d now startup!", quanta.id)
    end
    qxpcall_quit(startup, "quanta startup error: %s")
    quanta.init_flag = true
end
