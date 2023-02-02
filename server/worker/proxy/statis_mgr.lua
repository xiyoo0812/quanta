--statis_mgr.lua
import("driver/worker.lua")
import("kernel/object/linux.lua")

local ljson         = require("lcjson")

local json_encode   = ljson.encode

local log_path      = environ.get("QUANTA_STATIS_PATH")
local log_dump      = logfeature.dump("statis", log_path, true)

local event_mgr     = quanta.get("event_mgr")
local update_mgr    = quanta.get("update_mgr")
local linux_statis  = quanta.get("linux_statis")

local StatisMgr = singleton()
local prop = property(StatisMgr)
prop:reader("statis_datas", {})
prop:reader("statis_enable", false)     --统计开关

function StatisMgr:__init()
    local statis_enable = environ.status("QUANTA_STATIS")
    if statis_enable then
        self.statis_enable = statis_enable
        --定时处理
        update_mgr:attach_second5(self)
        --系统监控
        if quanta.platform == "linux" then
            linux_statis:setup()
        end
    end
    --事件监听
    event_mgr:add_listener(self, "on_rpc_send")
    event_mgr:add_listener(self, "on_rpc_recv")
    event_mgr:add_listener(self, "on_perfeval")
    event_mgr:add_listener(self, "on_proto_recv")
    event_mgr:add_listener(self, "on_proto_send")
    event_mgr:add_listener(self, "on_conn_update")
end

--输出到日志
function StatisMgr:flush()
    for _, measure in pairs(self.statis_datas) do
        log_dump(json_encode(measure))
    end
    self.statis_datas = {}
end

function StatisMgr:write_log(name, type, add_count)
    if self.statis_enable then
        self.statis_datas[#self.statis_datas + 1] = {
            name        = name,
            type        = type,
            value       = add_count,
            index       = quanta.index,
            service     = quanta.service,
            ser_name    = quanta.service_name,
        }
    end
end

-- 统计proto协议发送(KB)
function StatisMgr:on_proto_recv(cmd_id, send_len)
    self:write_log(cmd_id, "proto_recv", send_len)
end

-- 统计proto协议接收(KB)
function StatisMgr:on_proto_send(cmd_id, recv_len)
    self:write_log( cmd_id, "proto_send", recv_len)
end

-- 统计rpc协议发送(KB)
function StatisMgr:on_rpc_send(rpc, send_len)
    self:write_log(rpc, "rpc_send", send_len)
end

-- 统计rpc协议接收(KB)
function StatisMgr:on_rpc_recv(rpc, recv_len)
    self:write_log( rpc, "rpc_recv", recv_len)
end

-- 统计cmd协议连接
function StatisMgr:on_conn_update(conn_type, conn_count)
    self:write_log( conn_type, "conn", conn_count)
end

-- 统计性能
function StatisMgr:on_perfeval(eval_data, clock_ms)
    self:write_log(eval_data.eval_name, "perfeval", eval_data.yield_time)
end

-- 统计系统信息
function StatisMgr:on_second5()
    self:write_log("all_mem","system", self:_calc_mem_use())
    self:write_log("lua_mem","system", self:_calc_lua_mem())
    self:write_log("cpu_rate","system", self:_calc_cpu_rate())
    self:flush()
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
