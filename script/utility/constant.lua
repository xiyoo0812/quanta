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
KernCode.TOKEN_ERROR        = 9     --登录token错误
KernCode.DB_NOTINIT         = 10    --数据库没有初始化
KernCode.RPC_UNREACHABLE    = 11    --RPC目标不可达

--dx协议投flag掩码
local FlagMask              = enum("FlagMask", 0)
FlagMask.REQ                = 0x01  -- 请求
FlagMask.RES                = 0x02  -- 响应
FlagMask.ENCRYPT            = 0x04  -- 开启加密
FlagMask.QZIP               = 0x08  -- 开启qzip压缩

--网络时间常量定义
local NetwkTime             = enum("NetwkTime", 0)
NetwkTime.CONNECT_TIMEOUT   = 3000      --连接等待时间
NetwkTime.RPC_CALL_TIMEOUT  = 5000      --RPC调用超时时间
NetwkTime.HTTP_CALL_TIMEOUT = 4500      --HTTP调用超时时间
NetwkTime.MONGO_CALL_TIMEOUT= 5000      --MONGO调用超时时间
NetwkTime.ROUTER_TIMEOUT    = 10000     --router连接超时时间
NetwkTime.NETWORK_TIMEOUT   = 35000     --其他网络连接超时时间
NetwkTime.RECONNECT_TIME    = 5         --RPC连接重连时间（s）
NetwkTime.HEARTBEAT_TIME    = 1000      --RPC连接心跳时间

--常用时间周期
local PeriodTime = enum("PeriodTime", 0)
PeriodTime.HALF_MS          = 500       --0.5秒（ms）
PeriodTime.SECOND_MS        = 1000      --1秒（ms）
PeriodTime.SECOND_2_MS      = 2000      --2秒（ms）
PeriodTime.SECOND_3_MS      = 3000      --3秒（ms）
PeriodTime.SECOND_5_MS      = 5000      --5秒（ms）
PeriodTime.SECOND_10_MS     = 10000     --10秒（ms）
PeriodTime.SECOND_30_MS     = 30000     --30秒（ms）
PeriodTime.MINUTE_MS        = 60000     --60秒（ms）
PeriodTime.MINUTE_5_MS      = 300000    --5分钟（ms）
PeriodTime.MINUTE_10_MS     = 600000    --10分钟（ms）
PeriodTime.MINUTE_30_MS     = 1800000   --30分钟（ms）
PeriodTime.HOUR_MS          = 3600000   --1小时（ms）
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
PeriodTime.RAW_OFFSET_S     = 28800     --8小时 (s)

--数据加载状态
local DBLoading             = enum("DBLoading", 0)
DBLoading.INIT              = 0
DBLoading.LOADING           = 1
DBLoading.SUCCESS           = 2

-- GM命令类型
local GMType                = enum("GMType", 0)
GMType.PLAYER               = 0       -- 玩家相关
GMType.ROOM                 = 1       -- 房间系统相关
GMType.GLOBAL               = 2       -- 全局相关
GMType.AREA                 = 3       -- 小区相关

--数据库组定义
local DBGroup               = enum("DBGroup", 0)
DBGroup.AREA                = 1       -- 分区库
DBGroup.GLOBAL              = 2       -- 全局库
DBGroup.HASH                = 3       -- hash库

--Cache错误码
local CacheCode = enum("CacheCode", 0)
CacheCode.CACHE_NOT_SUPPERT         = 2051  -- 不支持的缓存类型
CacheCode.CACHE_PKEY_IS_NOT_EXIST   = 2052  -- Pkey不存在
CacheCode.CACHE_KEY_IS_NOT_EXIST    = 2053  -- key不存在
CacheCode.CACHE_FLUSH_FAILED        = 2054  -- flush失败
CacheCode.CACHE_KEY_LOCK_FAILD      = 2055  -- 用户锁失败
CacheCode.CACHE_DELETE_SAVE_FAILD   = 2056  -- 缓存删除失败
CacheCode.CACHE_IS_HOLDING          = 2057  -- 缓存正在处理
