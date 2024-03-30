--library.lua
local qgetenv   = quanta.getenv

--加载全局扩展库
if qgetenv("QUANTA_DYNAMIC") then
    --日志库
    require("lualog")
    --文件系统库
    require("lstdfs")
    --定时器库
    require("ltimer")
    --PB解析库
    require("luapb")
    --json库
    require("ljson")
    --bson库
    require("lbson")
    --编码库
    require("lcodec")
    --加密解密库
    require("lcrypt")

    --特定模块
    if qgetenv("QUANTA_MODE") then
        --aoi解析
        require("laoi")
        --Curl库
        require("lcurl")
        --网络库
        require("luabus")
        --detour库
        require("ldetour")
        --多线程库
        require("lworker")
        --unqlite
        require("lunqlite")
        --sqlite
        require("lsqlite")
        --lmdb
        require("lmdb")
    end
end
