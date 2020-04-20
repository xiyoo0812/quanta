--quanta_frame.lua
local lbus = require("luabus")
import("base/base.lua")
import("utility/signal.lua")
import("utility/service.lua")
import("utility/environ.lua")
import("utility/utility.lua")
import("kernel/perfeval_mgr.lua")
import("kernel/thread_mgr.lua")
import("kernel/timer_mgr.lua")
import("kernel/proto/sproto_mgr.lua")
import("kernel/proto/protobuf_mgr.lua")
import("kernel/statis/statis_mgr.lua")

local pairs         = pairs
local otime         = os.time
local ssub          = string.sub
local sfind         = string.find
local sformat       = string.format
local tinsert       = table.insert
local mrandomseed   = math.randomseed
local env_get       = environ.get
local env_number    = environ.number
local log_warn      = logger.warn
local log_info      = logger.info
local sid2name      = service.id2name
local smake_id      = service.make_id
local services      = service.groups
local signal_check  = signal.check
local collectgarbage= collectgarbage
local get_time_ms   = quanta.get_time_ms

local timer_mgr     = quanta.timer_mgr
local statis_mgr    = quanta.statis_mgr
local socket_mgr    = quanta.socket_mgr
local thread_mgr    = quanta.thread_mgr
local protobuf_mgr  = quanta.protobuf_mgr
local perfeval_mgr  = quanta.perfeval_mgr

--获取命令行参数
local function get_options(args, opts)
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

function quanta.init(service, opts, protos, enums)
    --初始化命令行参数
    local group = services[service]
    local options = get_options(quanta.args, opts)
    if not group then
        os.exit()
    end

    --初始化quanta环境
    quanta.frame = 0
    quanta.now = otime()
    quanta.group = group
    quanta.service = service
    quanta.options = options
    quanta.now_ms = get_time_ms()
    quanta.start_time = get_time_ms()
    quanta.index = tonumber(options.index)
    quanta.id = smake_id(group, options.index)
    quanta.pid = quanta.get_pid()
    quanta.name = sid2name(quanta.id)
    quanta.objects = {}
    quanta.dumps = {}

    --注册信号
    signal.init()
    --初始化环境变量
    environ.init(options)
    --初始化日志
    logger.init()

    log_info("pid: %d", quanta.pid)
    --初始化随机种子
    mrandomseed(quanta.start_time)

    -- 网络模块初始化
    socket_mgr = lbus.create_socket_mgr(env_number("ENV_MAX_CONNECTION"))
    quanta.socket_mgr = socket_mgr

    -- 初始核心管理器
    statis_mgr:setup()
    perfeval_mgr:setup()
    --默认使用protobuf协议
    protobuf_mgr:setup(protos, enums)

    -- 路由管理器初始化
    local router_group = env_get("ENV_ROUTER_GROUP")
    if router_group > 0 then
        import("kernel/router/router_mgr.lua")
        import("kernel/router/router_quanta_extend.lua")
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
        if signal_check() then
            for _, obj in pairs(quanta.dumps) do
                obj:dump(true)
            end
            log_info("service quit for signal !")
            quanta.run = nil
        end
    end
end
