--constant.lua

local ErrCode = enum("ErrCode", 0)

ErrCode.SUCCESS         = 0      --成功
ErrCode.LOGIC_FAILED    = 1      --业务执行失败
ErrCode.MYSQL_FAILED    = 2      --MYSQL执行失败
ErrCode.MONGO_FAILED    = 3      --MONGO执行失败
ErrCode.PARAM_ERROR     = 5      --业务参数错误
ErrCode.RPC_FAILED      = 6      --RPC调用失败

quanta.err_code = ErrCode
