-- admin_gm.lua
local log_info      = logger.info

local event_mgr     = quanta.get("event_mgr")
local admin_mgr     = quanta.get("admin_mgr")
local router_mgr    = quanta.get("router_mgr")

local LOCAL         = quanta.enum("GMType", "LOCAL")
local LOGIN         = quanta.enum("Service", "LOGIN")
local GATEWAY       = quanta.enum("Service", "GATEWAY")

local AdminGM = singleton()
function AdminGM:__init()
    self:register()
end

-- 注册
function AdminGM:register()
    local cmd_list = {
        {
            name = "add_proto_shield",
            gm_type = LOCAL,
            group = "运维",
            desc = "添加协议屏蔽",
            args = "start_cmd_id|integer count|integer",
            example = "add_proto_shield 11300 5",
            tip = "示例中，11300表示起始协议号，5表示范围(11300-11304)"
        },
        {
            name = "del_proto_shield",
            gm_type = LOCAL,
            group = "运维",
            desc = "删除协议屏蔽",
            args = "start_cmd_id|integer count|integer",
            example = "del_proto_shield 11300 5",
            tip = "示例中，11300表示起始协议号，5表示范围(11300-11304)"
        },
        {
            name = "shield_service_proto",
            gm_type = LOCAL,
            group = "运维",
            desc = "屏蔽服务协议",
            args = "server_type|integer status|bool",
            example = "set_service_proto_shield 0 1",
            tip = "示例中,设置指定协议处理服务(0:login/lobby,1:lobby,2:scene)上所有的协议屏蔽状态(1屏蔽0放开)"
        },
        {
            name = "set_logger_level",
            gm_type = LOCAL,
            group = "运维",
            desc = "设置服务日志等级",
            args = "service_id|integer level|integer",
            example = "set_logger_level 0 2",
            tip = "示例中,设置指定服务的日志输出等级"
        }
    }

    --注册GM
    admin_mgr:rpc_register_command(cmd_list, quanta.service)
    -- 初始化监听事件
    for _, cmd in ipairs(cmd_list) do
        event_mgr:add_trigger(self, cmd.name)
    end
end

-- 通知指定服务
function AdminGM:call_command_service(cmd_id, rpc, ...)
    local server_type = (cmd_id // 1000) % 10
    if server_type ~= 0 then
        router_mgr:broadcast(GATEWAY, rpc, ...)
    else
        router_mgr:broadcast(LOGIN, rpc, ...)
        router_mgr:broadcast(GATEWAY, rpc, ...)
    end
end

-- 添加协议屏蔽(多个)
function AdminGM:add_proto_shield(start_cmd_id, count)
    log_info("[AdminGM][add_proto_shield] start_cmd_id=%s count=%s", start_cmd_id, count)
    -- 通知服务
    self:call_command_service(start_cmd_id, "rpc_add_proto_shield", start_cmd_id, count)
end

-- 删除协议屏蔽(多个)
function AdminGM:del_proto_shield(start_cmd_id, count)
    log_info("[AdminGM][del_proto_shield] start_cmd_id=%s count=%s", start_cmd_id, count)
    -- 通知服务
    self:call_command_service(start_cmd_id, "rpc_del_proto_shield", start_cmd_id, count)
end

-- 屏蔽服务协议
function AdminGM:shield_service_proto(service_type, status)
    log_info("[AdminGM][shield_service_proto] service_type: %s, status:%s", service_type, status)
    -- 通知服务
    if service_type ~= 0 then
        router_mgr:broadcast(GATEWAY, "rpc_shield_service_proto", service_type, status)
    else
        router_mgr:broadcast(LOGIN, "rpc_shield_service_proto", service_type, status)
        router_mgr:broadcast(GATEWAY, "rpc_shield_service_proto", service_type, status)
    end
end

-- 设置日志等级
function AdminGM:set_logger_level(service_id, level)
    log_info("[AdminGM][set_logger_level] service_id: %s, level:%s", service_id, level)
    -- 通知服务
    router_mgr:broadcast(service_id, "rpc_set_logger_level", level)
end

-- export
quanta.admin_gm = AdminGM()

return AdminGM
