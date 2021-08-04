--kernel.lua

import("enum.lua")
import("class.lua")
import("mixin.lua")
import("property.lua")
import("basic/basic.lua")
import("utility/signal.lua")
import("utility/environ.lua")
import("utility/constant.lua")
import("utility/utility.lua")
import("kernel/config/config_mgr.lua")
import("kernel/statis/perfeval_mgr.lua")
import("kernel/basic/thread_mgr.lua")
import("kernel/basic/timer_mgr.lua")
import("kernel/basic/wheel_map.lua")

local pairs         = pairs
local otime         = os.time
local tinsert       = table.insert
local sig_check     = signal.check
local log_err       = logger.err
local log_warn      = logger.warn
local log_info      = logger.info
local env_get       = environ.get
local env_number    = environ.number
local get_time_ms   = quanta.get_time_ms
local collectgarbage= collectgarbage

local socket_mgr    = nil
local timer_mgr     = quanta.get("timer_mgr")
local thread_mgr    = quanta.get("thread_mgr")

--quanta启动
function quanta.startup()
    quanta.frame = 0
    quanta.now = otime()
    quanta.now_ms = get_time_ms()
    quanta.start_ms = get_time_ms()
    quanta.index = env_number("QUANTA_INDEX", 1)
    quanta.deploy = env_get("QUANTA_DEPLOY", "develop")
    local service_name = env_get("QUANTA_SERVICE")
    assert(service_name, "service not exist, quanta startup failed!")
    local service_id = service.init(service_name)
    assert(service_id, "service_id not exist, quanta startup failed!")
    quanta.service = service_name
    quanta.service_id = service_id
    quanta.id = service.make_id(service_name, quanta.index)
    quanta.name = service.make_nick(service_name, quanta.index)
    quanta.pid = quanta.get_pid()
    quanta.second_objs = {}
    quanta.minute_objs = {}
    quanta.frame_objs = {}
    quanta.hour_objs = {}
    quanta.quit_objs = {}
end

function quanta.init()
    import("utility/service.lua")
    --启动quanta
    quanta.startup()
    --初始化环境变量
    environ.init()
    --注册信号
    signal.init()
    --初始化日志
    logger.init()
    --初始化随机种子
    math.randomseed(quanta.start_ms)

    -- 网络模块初始化
    local lbus = require("luabus")
    local max_conn = env_number("QUANTA_MAX_CONN", 64)
    socket_mgr = lbus.create_socket_mgr(max_conn)
    quanta.socket_mgr = socket_mgr

    -- 初始化统计管理器
    quanta.perfeval_mgr:setup()
    import("kernel/statis/statis_mgr.lua")
    import("kernel/proto/protobuf_mgr.lua")

    --加载router配置
    local config_mgr = quanta.get("config_mgr")
    config_mgr:init_table("router", "index")
    --获取路由组配置
    local router_group = service.router_group(quanta.id)
    if not router_group then
        log_err("[quanta][init] %s router group is nil, check the service_cfg.lua!", quanta.name)
        os.exit()
    end
    --初始化路由管理器
    if next(router_group) then
        import("kernel/router/router_mgr.lua")
        quanta.router_mgr:setup(router_group)
        if env_get("QUANTA_FEISHU_URL") then
            --飞书上报
            import("driver/feishu.lua")
        end
    end
    if not env_get("QUANTA_MONITOR_HOST") then
        --加载monotor
        import("kernel/monitor/monitor_agent.lua")
        import("kernel/debug/netlog_mgr.lua")
    end
end

--初始化gm
function quanta.init_gm(gm_service)
    import("kernel/admin/gm_agent.lua")
    if gm_service then
        quanta.gm_agent:watch_service(gm_service)
    end
end

--垃圾回收
local last_tick = otime()
local function lua_collectgarbage()
    collectgarbage("step")
    if quanta.now - last_tick > 60 then
        last_tick = quanta.now
        collectgarbage("collect")
    end
end

--日常更新
function quanta.update()
    local count = socket_mgr.wait(10)
    --系统更新
    timer_mgr:update()
    thread_mgr:update()
    --业务更新
    local now_ms = get_time_ms()
    local escape_ms = now_ms - quanta.now_ms
    if escape_ms >= 100 then
        if escape_ms >= 400 then
            log_warn("[quanta][update] warning escape_ms(%d) too long count(%d)!", escape_ms, count)
        end
        quanta.now = otime()
        quanta.now_ms = now_ms
        local frame = (now_ms - quanta.start_ms) // 100
        for _, obj in pairs(quanta.frame_objs) do
            obj:on_frame(frame)
        end
        quanta.frame = frame
        if frame % 10 == 0 then
            --垃圾回收
            lua_collectgarbage()
            --检查信号
            if sig_check() then
                for _, obj in pairs(quanta.quit_objs) do
                    obj:on_quit()
                end
                log_info("service quit for signal !")
                timer_mgr:close()
                logger.close()
                quanta.run = nil
            end
        end
    end
end

--添加对象到小时更新循环
function quanta.attach_hour(obj)
    if not obj.on_hour then
        log_warn("[quanta][attach_hour] obj(%s) isn't on_hour method!", obj)
        return
    end
    quanta.hour_objs[obj] = true
end

function quanta.detach_hour(obj)
    quanta.hour_objs[obj] = nil
end

--添加对象到分更新循环
function quanta.attach_minute(obj)
    if not obj.on_minute then
        log_warn("[quanta][attach_minute] obj(%s) isn't on_minute method!", obj)
        return
    end
    quanta.minute_objs[obj] = true
end

function quanta.detach_minute(obj)
    quanta.minute_objs[obj] = nil
end

--添加对象到秒更新循环
function quanta.attach_second(obj)
    if not obj.on_second then
        log_warn("[quanta][attach_second] obj(%s) isn't on_second method!", obj)
        return
    end
    quanta.second_objs[obj] = true
end

function quanta.detach_second(obj)
    quanta.second_objs[obj] = nil
end

--添加对象到帧更新循环
function quanta.attach_frame(obj)
    if not obj.on_frame then
        log_warn("[quanta][attach_frame] obj(%s) isn't on_frame method!", obj)
        return
    end
    quanta.frame_objs[obj] = true
end

function quanta.detach_frame(obj)
    quanta.frame_objs[obj] = nil
end

--添加对象到程序退出通知列表
function quanta.attach_quit(obj)
    if not obj.on_quit then
        log_warn("[quanta][attach_quit] obj(%s) isn't on_quit method!", obj)
        return
    end
    quanta.quit_objs[obj] = true
end

function quanta.detach_quit(obj)
    quanta.quit_objs[obj] = nil
end
