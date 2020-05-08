--kernel.lua
import("basic/basic.lua")
import("utility/signal.lua")
import("utility/environ.lua")
import("utility/service.lua")
import("utility/constant.lua")
import("utility/utility.lua")
import("kernel/statis/perfeval_mgr.lua")
import("kernel/basic/thread_mgr.lua")
import("kernel/basic/timer_mgr.lua")
import("kernel/statis/statis_mgr.lua")
import("kernel/proto/protobuf_mgr.lua")

local pairs         = pairs
local otime         = os.time
local ssub          = string.sub
local sfind         = string.find
local sformat       = string.format
local tinsert       = table.insert
local sig_check     = signal.check
local log_warn      = logger.warn
local log_info      = logger.info
local env_get       = environ.get
local env_number    = environ.number
local get_time_ms   = quanta.get_time_ms
local collectgarbage= collectgarbage

local timer_mgr     = quanta.timer_mgr
local config_mgr    = quanta.config_mgr
local statis_mgr    = quanta.statis_mgr
local socket_mgr    = quanta.socket_mgr
local thread_mgr    = quanta.thread_mgr
local protobuf_mgr  = quanta.protobuf_mgr
local perfeval_mgr  = quanta.perfeval_mgr

--quanta启动
function quanta.startup()
    local quanta_service = env_get("QUANTA_SERVICE")
    assert(quanta_service, "service not exist, quanta startup failed!")
    local quanta_group = env_number("QUANTA_GROUP", 1)
    local quanta_index = env_number("QUANTA_INDEX", 1)
    local quanta_service_id = service.init(quanta_group, quanta_service)
    assert(quanta_service_id, "service_id not exist, quanta startup failed!")
    quanta.frame = 0
    quanta.now = otime()
    quanta.now_ms = get_time_ms()
    quanta.start_ms = get_time_ms()
    quanta.index = quanta_index
    quanta.group = quanta_group
    quanta.service = quanta_service
    quanta.service_id = quanta_service_id
    quanta.id = service.make_id(quanta_service_id, quanta_index)
    quanta.name = service.make_nick(quanta_service, quanta_index)
    quanta.pid = quanta.get_pid()
    quanta.objects = {}
    quanta.dumps = {}
end

function quanta.init()
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
    log_info("pid: %d", quanta.pid)

    -- 网络模块初始化
    local lbus = require("luabus")
    local max_conn = env_number("QUANTA_MAX_CONN", 64)
    socket_mgr = lbus.create_socket_mgr(max_conn)
    quanta.socket_mgr = socket_mgr

    -- 初始核心管理器
    statis_mgr:setup()
    perfeval_mgr:setup()

    --加载router配置
    config_mgr:init_table("router", "group", "index")
    --路由管理器初始化
    local router_group = service.router_group(quanta.service_id)
    if next(router_group) then
        import("kernel/router/router_mgr.lua")
        --初始化路由管理器
        quanta.router_mgr:setup(router_group)
    end
    if env_get("QUANTA_MONITOR_ADDR") then
        --加载monotor
        import("kernel/monitor/monitor_proxy.lua")
    end
end

--添加对象到主更新循环
function quanta.join(obj)
    if obj.update then
        tinsert(quanta.objects, obj)
    end
end

--添加对象到程序结束时的dump列表
function quanta.join_dump(obj)
    if obj.dump then
        tinsert(quanta.dumps, obj)
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
    local now_ms = get_time_ms()
    local escape_ms = now_ms - quanta.now_ms
    if escape_ms >= 100 then
        if escape_ms >= 400 then
            log_warn("warning escape_ms(%d) too long count(%d)!", escape_ms, count)
        end
        quanta.now = otime()
        quanta.now_ms = now_ms
        --系统更新
        timer_mgr:update(escape_ms)
        thread_mgr:update()
        --业务更新
        local frame = (now_ms - quanta.start_ms) // 100
        for _, obj in pairs(quanta.objects) do
            obj:update(frame)
        end
        quanta.frame = frame
        --垃圾回收
        if frame % 10 == 0 then
            lua_collectgarbage()
        end
        --检查信号
        if sig_check() then
            for _, obj in pairs(quanta.dumps) do
                obj:dump(true)
            end
            log_info("service quit for signal !")
            quanta.run = nil
        end
    end
end
