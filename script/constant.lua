--constant.lua

--核心基础错误(1-1000)
local KernCode = enum("KernCode", 0)
KernCode.SUCCESS            = 0     --成功
KernCode.FAILED             = 1     --系统错误，请重试
KernCode.TOO_FAST           = 2     --操作太快
KernCode.PARAM_ERROR        = 3     --业务参数错误
KernCode.UPHOLD             = 4     --服务维护
KernCode.RPC_FAILED         = 5     --RPC调用失败
KernCode.OPERATOR_SELF      = 6     --不能对自己操作
KernCode.PLAYER_NOT_EXIST   = 7     --玩家不存在
KernCode.TOKEN_ERROR        = 8     --登录token错误
KernCode.UNREACHABLE        = 9     --RPC目标不可达
KernCode.DB_NOTINIT         = 100   --数据库没有初始化
KernCode.LOGIC_FAILED       = 101   --业务执行失败
KernCode.MYSQL_FAILED       = 102   --MYSQL执行失败
KernCode.MONGO_FAILED       = 103   --MONGO执行失败
KernCode.REDIS_FAILED       = 104   --REDIS执行失败
KernCode.PGSQL_FAILED       = 105   --PGSQL执行失败

--网络时间常量定义
local NetwkTime             = enum("NetwkTime", 0)
NetwkTime.CONNECT_TIMEOUT   = 3000      --连接等待时间
NetwkTime.RPC_CALL_TIMEOUT  = 5000      --RPC调用超时时间
NetwkTime.HTTP_CALL_TIMEOUT = 5000      --HTTP调用超时时间
NetwkTime.DB_CALL_TIMEOUT   = 5000      --DB调用超时时间
NetwkTime.RPCLINK_TIMEOUT   = 20000     --RPC连接超时时间
NetwkTime.HEARTBEAT_TIME    = 8000      --RPC连接心跳时间
NetwkTime.NETWORK_TIMEOUT   = 30000     --心跳断线时间
NetwkTime.OFFLINE_TIMEOUT   = 45000     --掉线清理时间
NetwkTime.KICKOUT_TIMEOUT   = 80000     --强制清理时间

--常用时间周期
local PeriodTime = enum("PeriodTime", 0)
PeriodTime.FAST_MS          = 50        --50毫秒（ms）
PeriodTime.SLOW_MS          = 120       --120毫秒（ms）
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
PeriodTime.HOUR_M           = 60        --1小时（m

--在线状态
local OnlineStatus          = enum("OnlineStatus", 0)
OnlineStatus.LOADING        = 1
OnlineStatus.INLINE         = 2
OnlineStatus.OFFLINE        = 3
OnlineStatus.CLOSE          = 4

-- 随机类型
local RandType              = enum("RandType", 0)
RandType.ALONE              = 1       -- 独立随机
RandType.WHEEL              = 2       -- 轮盘随机

-- GM命令类型
local GMType                = enum("GMType", 0)
GMType.GLOBAL               = 0       -- 全局相关
GMType.PLAYER               = 1       -- 玩家相关, ID为玩家的ID
GMType.SERVICE              = 2       -- 服务相关, 转发所有服务
GMType.SYSTEM               = 3       -- 业务相关, ID为队伍ID,房间ID等
GMType.LOCAL                = 4       -- 本地事件转发
GMType.HASHKEY              = 5       -- 服务相关, ID按hash分发

-- robot类型
local RobotType             = enum("RobotType", 0)
RobotType.RANDOM            = 0       -- 随机账号
RobotType.COMPOSE           = 1       -- 组合账号
RobotType.PLAYER            = 2       -- 指定账号

--刷新时间
local FlushType             = enum("FlushType", 0)
FlushType.DAY               = 0       -- 每日0点刷新
FlushType.WEEK              = 1       -- 每周一刷新

--Cache错误码
local CacheCode = enum("CacheCode", 0)
CacheCode.CACHE_DB_LOAD_ERR     = 10001  -- DB加载失败
CacheCode.CACHE_DELETE_FAILD    = 10002  -- 缓存删除失败

--网络端口模式
local PortMode = enum("PortMode", 0)
PortMode.FIX                = 0     --固定端口号
PortMode.INCR               = 1     --端口累加模式，遇到冲突，端口号则加1
PortMode.INDUCE             = 2     --端口推导模式，按照运维参数推导端口号
