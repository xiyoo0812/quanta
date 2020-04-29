--quanta_frame.lua
require("sandbox.lua")
import("basic/basic.lua")
import("utility/signal.lua")
import("utility/service.lua")
import("utility/environ.lua")
import("utility/constant.lua")
import("utility/utility.lua")
import("kernel/statis/perfeval_mgr.lua")
import("kernel/basic/thread_mgr.lua")
import("kernel/basic/timer_mgr.lua")
import("kernel/statis/statis_mgr.lua")
import("kernel/proto/sproto_mgr.lua")
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
local get_time_ms   = quanta.get_time_ms
local collectgarbage= collectgarbage

local timer_mgr     = quanta.timer_mgr
local statis_mgr    = quanta.statis_mgr
local socket_mgr    = quanta.socket_mgr
local thread_mgr    = quanta.thread_mgr
local protobuf_mgr  = quanta.protobuf_mgr
local perfeval_mgr  = quanta.perfeval_mgr

--初始化命令行参数
local function options_init(args, opts)
    for _, arg in pairs(args) do
        if #arg > 2 and ssub(arg, 1, 2) == "--" then
            local pos = sfind(arg, "=", 1, true)
            if pos then
                local opt = ssub(arg, 3, pos - 1)
                opts[opt] = ssub(arg, pos + 1)
            end
        end
    end
    return opts
end

--初始化quanta环境
function quanta_env_init(options, service_name, service_id)
    quanta.frame = 0
    quanta.now = otime()
    quanta.service_id = service_id
    quanta.service_name = service_name
    quanta.options = options
    quanta.now_ms = get_time_ms()
    quanta.start_time = get_time_ms()
    quanta.index = tonumber(options.index)
    quanta.id = service.make_id(service_id, options.index)
    quanta.name = service.id2nick(quanta.id)
    quanta.pid = quanta.get_pid()
    quanta.objects = {}
    quanta.dumps = {}
end

function quanta.init(service_name, opts, protos, enums)
    --注册信号
    signal.init()
    --初始化服务节点
    log_info("pid: %d", quanta.pid)
    local service_id = service.init(service_name)
    if not service_id then
        os.exit()
    end
    --初始化命令行参数
    local options = options_init(quanta.args, opts)
    --初始化环境变量
    environ.init(options)
    --初始化quanta环境
    quanta_env_init(options, service_name, service_id)
    --初始化日志
    logger.init(options.index)
    --初始化随机种子
    math.randomseed(quanta.start_time)

    -- 网络模块初始化
    local lbus = require("luabus")
    local max_conn = environ.number("ENV_MAX_CONNECTION")
    socket_mgr = lbus.create_socket_mgr(max_conn)
    quanta.socket_mgr = socket_mgr

    -- 初始核心管理器
    statis_mgr:setup()
    perfeval_mgr:setup()
    --默认使用protobuf协议
    protobuf_mgr:setup(protos, enums)

    -- 路由管理器初始化
    local router_group = service.router_group(quanta.id)
    if next(router_group) then
        import("kernel/router/router_mgr.lua")
        quanta.router_mgr:setup(router_group)
    end
    if quanta.platform == "windows" then
        os.execute(sformat("title %s_%d", service, quanta.index))
    end
    return options
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
        local frame = (now_ms - quanta.start_time) // 100
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
