--constant.lua

--核心基础错误
local KernCode = enum("KernCode", 0)

KernCode.SUCCESS            = 0     --成功
KernCode.LOGIC_FAILED       = 1     --业务执行失败
KernCode.MYSQL_FAILED       = 2     --MYSQL执行失败
KernCode.MONGO_FAILED       = 3     --MONGO执行失败
KernCode.NETWORK_ERROR      = 4     --网络错误
KernCode.PARAM_ERROR        = 5     --业务参数错误
KernCode.RPC_FAILED         = 6     --RPC调用失败
KernCode.OPERATOR_SELF      = 7     --不能对自己操作
KernCode.PLAYER_NOT_EXIST   = 8     --不能对自己操作

--rpc 类型定义
local RpcType = enum("RpcType", 0)
RpcType.RPC_REQ = 0
RpcType.RPC_RES = 1

--网络时间常量定义
local NetwkTime = enum("NetwkTime", 0)
NetwkTime.CONNECT_TIMEOUT   = 3000      --连接等待时间
NetwkTime.RPC_CALL_TIMEOUT  = 5000      --RPC调用超时时间
NetwkTime.ROUTER_TIMEOUT    = 10000     --router连接超时时间
NetwkTime.NETWORK_TIMEOUT   = 35000     --其他网络连接超时时间
NetwkTime.RECONNECT_TIME    = 5         --RPC连接重连时间（s）
NetwkTime.HEARTBEAT_TIME    = 1000      --RPC连接心跳时间

--常用时间周期
local PeriodTime = enum("PeriodTime", 0)
PeriodTime.SECOND_MS        = 1000      --1秒（ms）
PeriodTime.SECOND_5_MS      = 5000      --5秒（ms）
PeriodTime.SECOND_10_MS     = 10000     --10秒（ms）
PeriodTime.SECOND_30_MS     = 30000     --30秒（ms）
PeriodTime.MINUTE_MS        = 60000     --60秒（ms）
PeriodTime.MINUTE_5_MS      = 300000    --5分钟（ms）
PeriodTime.MINUTE_10_MS     = 600000    --10分钟（ms）
PeriodTime.SECOND_5_S       = 5         --5秒（s）
PeriodTime.SECOND_10_S      = 10        --10秒（s）
PeriodTime.SECOND_30_S      = 30        --30秒（s）
PeriodTime.MINUTE_S         = 60        --60秒（s）
PeriodTime.MINUTE_5_S       = 300       --5分钟（s）
PeriodTime.MINUTE_10_S      = 600       --10分钟（s）
PeriodTime.MINUTE_30_S      = 1800      --30分钟（s）
PeriodTime.HOUR_S           = 3600      --1小时（s）
PeriodTime.DAY_S            = 86400     --1天（s）
PeriodTime.WEEK_S           = 604800    --1周（s）
PeriodTime.HOUR_M           = 60        --1小时（m）

--数据加载状态
local DBLoading = enum("DBLoading", 0)
DBLoading.INIT = 0
DBLoading.LOADING = 1
DBLoading.SUCCESS = 2
