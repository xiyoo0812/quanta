-- center_gm.lua
local log_err       = logger.err
local log_info      = logger.info
local make_sid      = service.make_sid
local name2sid      = service.name2sid

local gm_mgr        = quanta.get("gm_mgr")
local event_mgr     = quanta.get("event_mgr")
local router_mgr    = quanta.get("router_mgr")

local LOCAL         = quanta.enum("GMType", "LOCAL")

local CenterGM = singleton()
function CenterGM:__init()
    self:register()
end

-- 注册
function CenterGM:register()
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
        },
        {
            name = "show_snapshot",
            gm_type = LOCAL,
            group = "运维",
            desc = "显示系统快照",
            args = "service_name|string index|integer",
            example = "show_snapshot lobby 1",
            tip = "示例中,显示lobby1的系统快照"
        }
    }

    --注册GM
    gm_mgr:rpc_register_command(cmd_list)
    -- 初始化监听事件
    for _, cmd in ipairs(cmd_list) do
        event_mgr:add_listener(self, cmd.name)
    end
end

-- 通知指定服务
function CenterGM:call_command_service(cmd_id, rpc, ...)
    local server_type = (cmd_id // 1000) % 10
    if server_type ~= 0 then
        router_mgr:call_gateway_all(rpc, ...)
    else
        router_mgr:call_login_all(rpc, ...)
        router_mgr:call_gateway_all(rpc, ...)
    end
end

-- 添加协议屏蔽(多个)
function CenterGM:add_proto_shield(start_cmd_id, count)
    log_info("[CenterGM][add_proto_shield] start_cmd_id={} count={}", start_cmd_id, count)
    -- 通知服务
    self:call_command_service(start_cmd_id, "rpc_add_proto_shield", start_cmd_id, count)
end

-- 删除协议屏蔽(多个)
function CenterGM:del_proto_shield(start_cmd_id, count)
    log_info("[CenterGM][del_proto_shield] start_cmd_id={} count={}", start_cmd_id, count)
    -- 通知服务
    self:call_command_service(start_cmd_id, "rpc_del_proto_shield", start_cmd_id, count)
end

-- 屏蔽服务协议
function CenterGM:shield_service_proto(service_type, status)
    log_info("[CenterGM][shield_service_proto] service_type: {}, status:{}", service_type, status)
    -- 通知服务
    if service_type ~= 0 then
        router_mgr:call_gateway_all("rpc_shield_service_proto", service_type, status)
    else
        router_mgr:call_login_all("rpc_shield_service_proto", service_type, status)
        router_mgr:call_gateway_all("rpc_shield_service_proto", service_type, status)
    end
end

-- 设置日志等级
function CenterGM:set_logger_level(service_id, level)
    log_info("[CenterGM][set_logger_level] service_id: {}, level:{}", service_id, level)
    -- 通知服务
    router_mgr:broadcast(service_id, "rpc_set_logger_level", level)
end

-- 显示系统快照
function CenterGM:show_snapshot(service_name, index)
    log_info("[CenterGM][show_snapshot] service_name: {}, index:{}", service_name, index)
    -- 通知服务
    local quanta_id = make_sid(name2sid(service_name), index)
    if service_name == "router" then
        local ok, codeoe, res = router_mgr:call_router_id(quanta_id, "rpc_show_snapshot")
        if not ok then
            log_err("[CenterGM][show_snapshot] exec service={}-{} failed! codeoe={},res={}", service_name, index, codeoe, res)
        end
        return codeoe, res
    end
    local ok, codeoe, res = router_mgr:call_target(quanta_id, "rpc_show_snapshot")
    if not ok then
        log_err("[CenterGM][show_snapshot] exec service={}-{} failed! codeoe={},res={}", service_name, index, codeoe, res)
    end
    return codeoe, res
end

-- export
quanta.center_gm = CenterGM()

return CenterGM
