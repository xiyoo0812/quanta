--constant.lua

local KernelCode = enum("KernelCode", 0)

KernelCode.SUCCESS      = 0      --成功
KernelCode.LOGIC_FAILED = 1      --业务执行失败
KernelCode.MYSQL_FAILED = 2      --MYSQL执行失败
KernelCode.MONGO_FAILED = 3      --MONGO执行失败
KernelCode.PARAM_ERROR  = 5      --业务参数错误
KernelCode.RPC_FAILED   = 6      --RPC调用失败
