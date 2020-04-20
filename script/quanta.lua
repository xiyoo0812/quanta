--quanta_frame.lua
local lbus = require("luabus")
import("common/base.lua")
import("share/signal.lua")
import("share/router/service.lua")
import("share/environ.lua")
import("share/core/perfeval_mgr.lua")
import("share/core/thread_mgr.lua")
import("share/core/protobuf_mgr.lua")
import("share/core/timer_mgr.lua")
import("share/statis/statis_mgr.lua")

local pairs         = pairs
local otime         = os.time
local ssub          = string.sub
local sfind         = string.find
local sformat       = string.format
local tinsert       = table.insert
local mrandomseed   = math.randomseed
local env_get       = environ.get
local env_number    = environ.number
local signal_check  = signal.check
local sid2name      = service.id2name
local smake_id      = service.make_id
local services      = service.groups
local log_warn      = logger.warn
local log_info      = logger.info
local get_time_ms   = quanta.get_time_ms
local collectgarbage = collectgarbage

local timer_mgr     = quanta.timer_mgr
local statis_mgr    = quanta.statis_mgr
local socket_mgr    = quanta.socket_mgr
local protobuf_mgr  = quanta.protobuf_mgr
local thread_mgr = quanta.thread_mgr
local perfeval_mgr  = quanta.perfeval_mgr

local function get_options(args, confs)
    for _, arg in pairs(args) do
        if #arg > 2 and ssub(arg, 1, 2) == "--" then
            local pos = sfind(arg, "=", 1, true)
            if pos then
                local opt = ssub(arg, 3, pos - 1)
                confs[opt] = ssub(arg, pos + 1)
            end
        end
    end
    return confs
end

local last_tick = otime()
local function lua_collectgarbage()
    collectgarbage("step")
    if quanta.now - last_tick > 60 then
        last_tick = quanta.now
        collectgarbage("collect")
    end
end

function quanta.init(service, confs, protos, enums)
    --初始化配置
    local group = services[service]
    local options = get_options(quanta.args, confs)
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
    --初始化配置和常量名字空间
    import("share/const.lua")
    -- 初始核心管理器
    statis_mgr:setup()
    perfeval_mgr:setup()
    --初始化日志
    logger.init()

    log_info("pid: %d", quanta.pid)
    --初始化随机种子
    mrandomseed(quanta.start_time)
    -- 网络模块初始化
    socket_mgr = lbus.create_socket_mgr(env_number("ENV_MAX_CONNECTION"))
    quanta.socket_mgr = socket_mgr

    -- 协议加载
    local protos_ = protos or {}
    tinsert(protos_, 1, "common")
    tinsert(protos_, 1, "ncmd_cs")
    tinsert(protos_, 1, "errcode_cs")
    tinsert(protos_, 1, "ncmd_monitor")
    tinsert(protos_, 1, "ncmd_platform")

    protobuf_mgr:setup(protos_)

    local enums_ = enums or {}
    enums_.err = {"Code"}
    enums_.ncmd_cs = {"NCmdId"}
    enums_.ncmd_monitor = {"NCmdId", "NodeCmdId"}
    enums_.ncmd_platform = {"CCmdId", "ErrCode"}
    protobuf_mgr:define_enum(enums_)
    protobuf_mgr:define_proto(protos_)

    -- 常量初始化
    import("share/const.lua")
    --初始化通用业务
    import("share/utility.lua")

    -- 路由管理器初始化
    if group ~= services.router and group ~= services.monitor and group ~= services.robot then
        import("share/router/router_mgr.lua")
        import("share/router/router_lua_extend.lua")
        quanta.router_mgr:setup(env_get("ENV_ROUTER_GROUP"))
    end

    if group ~= services.monitor and group ~= services.robot then
        import("share/monitor/monitor_agent.lua")
        import("share/monitor/online_log_mgr.lua")
    end

    if quanta.platform == "windows" then
        os.execute(sformat("title %s_%d", service, quanta.index))
    end
    return options
end

function quanta.join(obj)
    if obj.update then
        tinsert(quanta.objects, obj)
    end
end

function quanta.join_dump(obj)
    if obj.dump then
        tinsert(quanta.dumps, obj)
    end
end

function quanta.update()
    --日常更新
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
