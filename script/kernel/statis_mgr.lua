--statis_mgr.lua
import("kernel/object/linux.lua")

local pairs         = pairs
local log_info      = logger.info
local sformat       = string.format
local env_status    = environ.status

local timer_mgr     = quanta.get("timer_mgr")
local linux_statis  = quanta.get("linux_statis")
local update_mgr    = quanta.get("update_mgr")

local PeriodTime    = enum("PeriodTime")

local StatisMgr = singleton()
function StatisMgr:__init()
    -- 统计开关
    self.statis_status  = false
    -- 统计辅助开关
    self.statis_pack    = false --统计pack请求
    self.statis_rpc     = true  --统计rpc请求
    self.statis_flow    = true  --统计流量
    self.statis_conn    = false --统计连接
    self.statis_child   = false --统计子项目
    self.statis_cpu     = true  --统计cpu信息
    self.statis_mem     = false --统计内存信息
    -- 分钟辅助统计（满60清零）
    self.escape_ms      = 0
    self.escape_minute  = 0
    -- 统计数据
    -- pack_send        pack send 统计
    -- pack_recv        pack recv 统计
    -- pack_send_flow   pack send flow统计
    -- pack_recv_flow   pack recv flow统计
    -- rpc_send         rpc send 统计
    -- rpc_recv         rpc recv 统计
    -- rpc_send_flow    rpc send flow统计
    -- rpc_recv_flow    rpc recv flow统计
    -- conn_info        conn 统计
    -- cpu_info         cpu 统计
    -- mem_info         mem 统计
    -- lua_mem          lua mem 统计
    -- co_info          协程 统计
    self.statis_list    = {}

    --setup
    self:setup()
end

--初始化
function StatisMgr:setup()
    if quanta.platform == "linux" then
        linux_statis:setup()
    end
    self.statis_status  = env_status("QUANTA_STATIS")
    -- 退出通知
    update_mgr:attach_quit(self)
    -- 定时器
    timer_mgr:loop(PeriodTime.SECOND_MS, function(escape)
        self:on_timer(escape)
    end)
end

function StatisMgr:on_quit()
    self:dump(true)
end

--初始化 统计节点
function StatisMgr:init_statis_node()
    return {
        count_s = 0,    --<秒>计数器
        count_m = 0,    --<分>计数器
        count_h = 0,    --<时>计数器
        count_t = 0,    --<累计>计数器
        count_tm = 0,   --<分更新次数>计数器
        count_th = 0,   --<时更新次数>计数器
        count_ps = 0,   --<上一秒>计数器
        count_pm = 0,   --<上一分>计数器
        count_ph = 0,   --<上一时>计数器
        count_hs = 0,   --<每秒最高>计数器
        count_hm = 0,   --<每分最高>计数器
        count_hh = 0,   --<每时最高>计数器
        childs = {},    --子节点数据统计
    }
end

-- 获取 统计节点
function StatisMgr:get_statis_node(node_name)
    local node = self.statis_list[node_name]
    if not node then
        node = self:init_statis_node()
        self.statis_list[node_name] = node
    end
    return node
end

-- 获取 统计子节点
function StatisMgr:get_child_node(node, child_name)
    local child_node = node.childs[child_name]
    if not child_node then
        child_node = self:init_statis_node()
        node.childs[child_name] = child_node
    end
    return child_node
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

-- 定时器
function StatisMgr:on_timer(escape)
    if not self.statis_status then
        return
    end
    self.escape_ms = self.escape_ms + escape
    -- 秒
    self:_second_update()
    -- 分钟
    if self.escape_ms >= PeriodTime.MINUTE_MS then
        self.escape_minute = self.escape_minute + 1
        self.escape_ms = self.escape_ms - PeriodTime.MINUTE_MS
        self:_minute_update()
    --    self:dump(false)
    end
    -- 小时
    if self.escape_minute >= PeriodTime.HOUR_M then
        self.escape_minute = 0
        self:_hour_update()
        self:dump(true)
    end
    -- 10秒统计系统信息
    if (self.escape_ms // PeriodTime.SECOND_MS) % 10 == 0 then
        self:system_update()
    end
end

-- 统计pack协议发送(KB)
function StatisMgr:on_pack_send(cmd_id, send_len)
    if self.statis_pack then
        local pack_send = self:get_statis_node("pack_send")
        pack_send.count_s = pack_send.count_s + 1
        if self.statis_child then
            local child_pack_send = self:get_child_node(pack_send, cmd_id)
            child_pack_send.count_s = child_pack_send.count_s + 1
        end
        if self.statis_flow then
            local send_kb = send_len / 1000
            local pack_send_flow = self:get_statis_node("pack_send_flow")
            pack_send_flow.count_s = pack_send_flow.count_s + send_kb
            if self.statis_child then
                local child_pack_send_flow = self:get_child_node(pack_send_flow, cmd_id)
                child_pack_send_flow.count_s = child_pack_send_flow.count_s + send_kb
            end
        end
    end
end

-- 统计pack协议接收(KB)
function StatisMgr:on_pack_recv(cmd_id, recv_len)
    if self.statis_pack then
        local pack_recv = self:get_statis_node("pack_recv")
        pack_recv.count_s = pack_recv.count_s + 1
        if self.statis_child then
            local child_pack_recv = self:get_child_node(pack_recv, cmd_id)
            child_pack_recv.count_s = child_pack_recv.count_s + 1
        end
        if self.statis_flow then
            local recv_kb = recv_len / 1000
            local pack_recv_flow = self:get_statis_node("pack_recv_flow")
            pack_recv_flow.count_s = pack_recv_flow.count_s + recv_kb
            if self.statis_child then
                local child_pack_recv_flow = self:get_child_node(pack_recv_flow, cmd_id)
                child_pack_recv_flow.count_s = child_pack_recv_flow.count_s + recv_kb
            end
        end
    end
end

-- 统计rpc协议发送(KB)
function StatisMgr:on_rpc_send(rpc, send_len)
    if self.statis_rpc then
        local rpc_send = self:get_statis_node("rpc_send")
        rpc_send.count_s = rpc_send.count_s + 1
        if self.statis_child then
            local child_rpc_send = self:get_child_node(rpc_send, rpc)
            child_rpc_send.count_s = child_rpc_send.count_s + 1
        end
        if self.statis_flow then
            local send_kb = send_len / 1000
            local rpc_send_flow = self:get_statis_node("rpc_send_flow")
            rpc_send_flow.count_s = rpc_send_flow.count_s + send_kb
            if self.statis_child then
                local child_rpc_send_flow = self:get_child_node(rpc_send_flow, rpc)
                child_rpc_send_flow.count_s = child_rpc_send_flow.count_s + send_kb
            end
        end
    end
end

-- 统计rpc协议接收(KB)
function StatisMgr:on_rpc_recv(rpc, recv_len)
    if self.statis_rpc then
        local rpc_recv = self:get_statis_node("rpc_recv")
        rpc_recv.count_s = rpc_recv.count_s + 1
        if self.statis_child then
            local child_rpc_recv = self:get_child_node(rpc_recv, rpc)
            child_rpc_recv.count_s = child_rpc_recv.count_s + 1
        end
        if self.statis_flow then
            local recv_kb = recv_len / 1000
            local rpc_recv_flow = self:get_statis_node("rpc_recv_flow")
            rpc_recv_flow.count_s = rpc_recv_flow.count_s + recv_kb
            if self.statis_child then
                local child_rpc_recv_flow = self:get_child_node(rpc_recv_flow, rpc)
                child_rpc_recv_flow.count_s = child_rpc_recv_flow.count_s + recv_kb
            end
        end
    end
end

-- 统计pack协议连接
function StatisMgr:on_pack_conn_update(conn_type, conn_count)
    if self.statis_conn then
        local conn_info = self:get_statis_node("conn_info")
        local conn = self:get_child_node(conn_info, conn_type)
        conn.count_m = conn.count_m + conn_count
        conn.count_tm = conn.count_tm + 1
        conn.count_ps = conn_count
        --设置替换型统计
        conn.replace = true
    end
end

-- 统计系统信息
function StatisMgr:system_update()
    if self.statis_cpu then
        --统计 cpu_rate
        local cpu_rate = self:_calc_cpu_rate()
        local cpu_info = self:get_statis_node("cpu_info")
        cpu_info.count_m = cpu_info.count_m + cpu_rate
        cpu_info.count_tm = cpu_info.count_tm + 1
        cpu_info.count_ps = cpu_rate
        cpu_info.replace = true
    end
    if self.statis_mem then
        --统计 mem_info
        local mem_use = self:_calc_mem_use()
        local mem_info = self:get_statis_node("mem_info")
        mem_info.count_m = mem_info.count_m + mem_use
        mem_info.count_tm = mem_info.count_tm + 1
        mem_info.count_ps = mem_use
        mem_info.replace = true
        --统计 lua内存
        local lua_mem = self:_calc_lua_mem()
        local lua_mem_info = self:get_statis_node("lua_mem")
        lua_mem_info.count_m = lua_mem_info.count_m + lua_mem
        lua_mem_info.count_tm = lua_mem_info.count_tm + 1
        lua_mem_info.count_ps = lua_mem
        lua_mem_info.replace = true
    end
end

-- 秒更新
function StatisMgr:_second_update()
    local function second_list_update(list)
        local function second_update(node)
            if not node.replace then
                node.count_m = node.count_m + node.count_s
                node.count_ps = node.count_s
                node.count_s = 0
            end
            if node.count_ps > node.count_hs then
                node.count_hs = node.count_ps
            end
            second_list_update(node.childs)
        end
        for _, node in pairs(list) do
            second_update(node)
        end
    end
    second_list_update(self.statis_list)
end

-- 分钟更新
function StatisMgr:_minute_update()
    local function minute_list_update(list)
        local function minute_update(node)
            if node.replace then
                if node.count_tm > 0 then
                    node.count_pm = node.count_m / node.count_tm
                    node.count_th = node.count_th + node.count_tm
                    node.count_tm = 0
                else
                    node.count_pm = node.count_ps
                end
            else
                node.count_h = node.count_h + node.count_m
                node.count_pm = node.count_m
            end
            if node.count_pm > node.count_hm then
                node.count_hm = node.count_pm
            end
            node.count_m = 0
            minute_list_update(node.childs)
        end
        for _, node in pairs(list) do
            minute_update(node)
        end
    end
    minute_list_update(self.statis_list)
end

-- 小时更新
function StatisMgr:_hour_update()
    local function hour_list_update(list)
        local function hour_update(node)
            if node.replace then
                if node.count_th > 0 then
                    node.count_ph = node.count_h / node.count_th
                    node.count_th = 0
                else
                    node.count_ph = node.count_pm
                end
            else
                node.count_ph = node.count_h
            end
            if node.count_ph > node.count_hh then
                node.count_hh = node.count_ph
            end
            node.count_h = 0
            hour_list_update(node.childs)
        end
        for _, node in pairs(list) do
            hour_update(node)
        end
    end
    hour_list_update(self.statis_list)
end

-- dump统计
function StatisMgr:dump(whole)
    if not self.statis_status then
        return
    end
    local function dump_list(list, parent_name)
        local function dump_node(key, node, par_name)
            local output
            if node.replace then
                output = sformat("%s=>ps:(R:%.1f, H:%.1f), pm:(R:%.1f, H:%.1f), ph:(R:%.1f, H:%.1f)",
                    key, node.count_ps, node.count_hs, node.count_pm, node.count_hm, node.count_ph, node.count_hh)
            else
                output = sformat("%s=>ps:(R:%.1f, P:%.1f, H:%.1f), pm:(R:%.1f, P:%.1f, H:%.1f), ph:(R:%.1f, P:%.1f, H:%.1f))",
                    key, node.count_s, node.count_ps, node.count_hs, node.count_m, node.count_pm,
                    node.count_hm, node.count_h, node.count_hh, node.count_hh)
            end
            if par_name then
                output = sformat("%s.%s %s", par_name, output, whole and node.count_t or "")
            end
            --输出统计信息
            log_info(output)
            --递归dump子节点
            if whole then
                dump_list(node.childs, key)
            end
        end
        for key, node in pairs(list) do
            dump_node(key, node, parent_name)
        end
    end
    log_info("quanta system statis infos dump:")
    log_info("----------------------------------------------------")
    dump_list(self.statis_list)
    log_info("----------------------------------------------------")
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
