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
local RpcType = enum("RpcType", 0, "RPC_REQ", "RPC_RES")

--网络时间常量定义
local NetwkTime = enum("NetwkTime", 0)
NetwkTime.CONNECT_TIMEOUT   = 3000      --连接等待时间
NetwkTime.RPC_CALL_TIMEOUT  = 5000      --RPC调用超时时间
NetwkTime.ROUTER_TIMEOUT    = 10000     --router连接超时时间
NetwkTime.NETWORK_TIMEOUT   = 35000     --其他网络连接超时时间
NetwkTime.RECONNECT_TIME    = 5         --RPC连接重连时间
NetwkTime.HEARTBEAT_TIME    = 1000      --RPC连接心跳时间

--数据加载状态
local DBLoading = enum("DBLoading", 0, "INIT", "LOADING", "SUCCESS")
