-- router_extend
local ljson = require("luacjson")
ljson.encode_sparse_array(true)

local pairs             = pairs
local mhuge             = math.huge
local mtointeger        = math.tointeger
local log_err           = logger.err
local json_decode       = ljson.decode
local tinsert           = table.insert
local env_table         = environ.table
local services          = service.groups
local ssplit            = quanta_extend.split

local errcode           = err.Code

local timer_mgr         = quanta.timer_mgr
local router_mgr        = quanta.router_mgr

local ROUTER_GROUP_CFG  = import("config/router_cfg.lua")

local TIME_PERIOD       = 30 * 1000

local RouterExtend = singleton()
function RouterExtend:__init()
    self:setup()
end

function RouterExtend:setup()
    -- 过滤服务器组
    if quanta.group == services.router or quanta.group == services.monitor or quanta.group == services.robot then
        return
    end
    timer_mgr:loop(TIME_PERIOD, function()
        self:timer_update_router_config()
    end)
    router_mgr:add_trigger(self, "web_pull_router_ntf")
end

-- 定时拉取路由配置
function RouterExtend:timer_update_router_config()
    self:get_config_from_web()
end

-- 从web服务器拉取路由配置
function RouterExtend:get_config_from_web()
    local send_data = {}
    local router_group = env_table("ENV_ROUTER_GROUP")
    for _, str_id in pairs(router_group) do
        local group_id = tonumber(str_id)
        local cfg = ROUTER_GROUP_CFG[group_id]
        local version = mhuge
        for _, data in pairs(cfg.routers_addr) do
            if version > data.version then
                version = data.version
            end
        end
        tinsert(send_data, {group = group_id, version = version})
    end

    local ret, res = self:send_web_request(send_data)
    if not ret then
        return
    end

    local json_data = json_decode(res)
    --log_info("[RouterExtend][get_config_from_web]->json_data:%s", serialize(json_data))
    for _, data in pairs(json_data.ret_data) do
        if type(data.routers) ~= "table" then
            break
        end

        local group_id = mtointeger(data.group_id)
        local cfg = ROUTER_GROUP_CFG[group_id]
        if not cfg then
            log_err("[RouterExtend][get_config_from_web]->get ROUTER_GROUP_CFG failed! group_id:%s, data.group_id:%s", group_id, data.group_id)
            return
        end

        cfg.svr_names = ssplit(data.svrs, ",")

        for _, new in pairs(data.routers) do
            local flag = false
            local new_index, new_version = mtointeger(new.index), mtointeger(new.version)
            for _, old in pairs(cfg.routers_addr) do
                if new_index == old.index then
                    old.version = new_version
                    old.addr = new.addr
                    flag = true
                    break
                end
            end

            if not flag then
                tinsert(cfg.routers_addr, {addr = new.addr, index = new_index, version = new_version})
            end
        end

        router_mgr:update_router_cfg(group_id)
    end
end

-- 发送web请求
function RouterExtend:send_web_request(send_data)
    if not next(send_data) then
        return false
    end

    local ok, code, res = quanta.monitor:service_request("router_cfg", send_data)
    if not ok or errcode.SUCCESS ~= code then
        --log_err("[RouterExtend][get_config_from_web] failed! service_request failed: %s, %s, %s", ok, code, res)
        return false
    end

    return true, res
end

-- web服务器通知拉取router配置
function RouterExtend:web_pull_router_ntf()
    -- 过滤服务器组
    if quanta.group == services.router or quanta.group == services.monitor or quanta.group == services.robot then
        return
    end

    self:get_config_from_web()
end

quanta.router_extend = RouterExtend()

return RouterExtend
