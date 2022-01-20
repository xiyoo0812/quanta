--statis_mgr.lua
import("kernel/object/linux.lua")
local InfluxDB = import("driver/influx.lua")

local env_get       = environ.get
local env_addr      = environ.addr
local env_status    = environ.status

local event_mgr     = quanta.get("event_mgr")
local update_mgr    = quanta.get("update_mgr")
local thread_mgr    = quanta.get("thread_mgr")
local linux_statis  = quanta.get("linux_statis")

local StatisMgr = singleton()
local prop = property(StatisMgr)
prop:reader("influx", nil)              --influx
prop:reader("statis_status", false)     --统计开关
function StatisMgr:__init()
    local org = env_get("QUANTA_INFLUX_ORG")
    local token = env_get("QUANTA_INFLUX_TOKEN")
    local bucket = env_get("QUANTA_INFLUX_BUCKET")
    local ip, port = env_addr("QUANTA_INFLUX_ADDR")
    --初始化参数
    self.statis_status = env_status("QUANTA_STATIS")
    self.influx = InfluxDB(ip, port, org, bucket, token)
    --事件监听
    event_mgr:add_listener(self, "on_rpc_send")
    event_mgr:add_listener(self, "on_rpc_recv")
    event_mgr:add_listener(self, "on_perfeval")
    event_mgr:add_listener(self, "on_proto_recv")
    event_mgr:add_listener(self, "on_proto_send")
    event_mgr:add_listener(self, "on_conn_update")
    --定时处理
    update_mgr:attach_minute(self)
    --系统监控
    if quanta.platform == "linux" then
        linux_statis:setup()
    end
end

-- 发送给influx
function StatisMgr:write(measurement, tags, fields)
    thread_mgr:fork(function()
        self.influx:write(measurement, tags, fields)
    end)
end

-- 统计proto协议发送(KB)
function StatisMgr:on_proto_recv(cmd_id, send_len)
    local tags = {
        name = cmd_id,
        type = "proto_recv",
        index = quanta.index,
        service = quanta.service
    }
    local fields = { count = send_len }
    self:write("network", tags, fields)
end

-- 统计proto协议接收(KB)
function StatisMgr:on_proto_send(cmd_id, recv_len)
    local tags = {
        name = cmd_id,
        type = "proto_send",
        index = quanta.index,
        service = quanta.service
    }
    local fields = { count = recv_len }
    self:write("network", tags, fields)
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
    self:write("network", tags, fields)
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
    self:write("network", tags, fields)
end

-- 统计cmd协议连接
function StatisMgr:on_conn_update(conn_type, conn_count)
    local tags = {
        type = "conn",
        name = conn_type,
        index = quanta.index,
        service = quanta.service
    }
    local fields = { count = conn_count }
    self:write("network", tags, fields)
end

-- 统计性能
function StatisMgr:on_perfeval(eval_data, now_ms)
    local tags = {
        index = quanta.index,
        service = quanta.service,
        name = eval_data.eval_name
    }
    local tital_time = now_ms - eval_data.begin_time
    local fields = {
        tital_time = tital_time,
        yield_time = eval_data.yield_time,
        eval_time = tital_time - eval_data.yield_time
    }
    self:write("perfeval", tags, fields)
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
        self:write("system", tags, fields)
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
