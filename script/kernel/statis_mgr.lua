--statis_mgr.lua
import("agent/influx_agent.lua")
import("kernel/object/linux.lua")

local env_status    = environ.status

local linux_statis  = quanta.get("linux_statis")
local update_mgr    = quanta.get("update_mgr")
local influx_agent  = quanta.get("influx_agent")

local StatisMgr = singleton()
local prop = property(StatisMgr)
prop:reader("statis_status", false)     --统计开关
function StatisMgr:__init()
    if quanta.platform == "linux" then
        linux_statis:setup()
    end
    self.statis_status = env_status("QUANTA_STATIS")
    -- 退出通知
    update_mgr:attach_minute(self)
end

-- 统计系统入口
function StatisMgr:statis_notify(event, ...)
    if self.statis_status then
        local handler = StatisMgr[event]
        if handler then
            handler(self, ...)
        end
    end
end

-- 统计pack协议发送(KB)
function StatisMgr:on_pack_send(cmd_id, send_len)
    local tags = {
        name = cmd_id,
        type = "pack_send",
        index = quanta.index,
        service = quanta.service
    }
    local fields = { count = send_len }
    influx_agent:write("network", tags, fields)
end

-- 统计pack协议接收(KB)
function StatisMgr:on_pack_recv(cmd_id, recv_len)
    local tags = {
        name = cmd_id,
        type = "pack_recv",
        index = quanta.index,
        service = quanta.service
    }
    local fields = { count = recv_len }
    influx_agent:write("network", tags, fields)
end

-- 统计rpc协议发送(KB)
function StatisMgr:on_rpc_send(rpc, send_len)
    local tags = {
        name = rpc,
        type = "rpc_send",
        index = quanta.index,
        service = quanta.service
    }
    local fields = { count = send_len }
    influx_agent:write("network", tags, fields)
end

-- 统计rpc协议接收(KB)
function StatisMgr:on_rpc_recv(rpc, recv_len)
    local tags = {
        name = rpc,
        type = "rpc_recv",
        index = quanta.index,
        service = quanta.service
    }
    local fields = { count = recv_len }
    influx_agent:write("network", tags, fields)
end

-- 统计pack协议连接
function StatisMgr:on_pack_conn_update(conn_type, conn_count)
    local tags = {
        type = "conn",
        name = conn_type,
        index = quanta.index,
        service = quanta.service
    }
    local fields = { count = conn_count }
    influx_agent:write("network", tags, fields)
end

-- 统计系统信息
function StatisMgr:on_minute(now)
    if self.statis_status then
        local tags = {
            index = quanta.index,
            service = quanta.service
        }
        local fields = {
            all_mem = self:_calc_mem_use(),
            lua_mem = self:_calc_lua_mem(),
            cpu_rate = self:_calc_cpu_rate(),
        }
        influx_agent:write("system", tags, fields)
    end
end

-- 计算lua内存信息(KB)
function StatisMgr:_calc_lua_mem()
    return collectgarbage("count")
end

-- 计算内存信息(KB)
function StatisMgr:_calc_mem_use()
    if quanta.platform == "linux" then
        return linux_statis:calc_memory()
    end
    return 5000
end

-- 计算cpu使用率
function StatisMgr:_calc_cpu_rate()
    if quanta.platform == "linux" then
        return linux_statis:calc_cpu_rate()
    end
    return 0.1
end

quanta.statis_mgr = StatisMgr()

return StatisMgr
