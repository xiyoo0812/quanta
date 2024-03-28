--library.lua
local qgetenv   = quanta.getenv

--加载全局扩展库，使用顶级域名
local librarys = {
    --日志库
    log = require("lualog"),
    --文件系统库
    stdfs = require("lstdfs"),
    --定时器库
    timer = require("ltimer"),
    --PB解析库
    protobuf = require("luapb"),
    --json库
    json = require("ljson"),
    --bson库
    bson = require("lbson"),
    --编码库
    codec = require("lcodec"),
    --加密解密库
    crypt = require("lcrypt")
}

--特定模块
if qgetenv("QUANTA_MODE") then
    --aoi解析
    librarys.aoi = require("laoi")
    --Curl库
    librarys.curl = require("lcurl")
    --网络库
    librarys.luabus = require("luabus")
    --detour库
    librarys.detour = require("ldetour")
    --多线程库
    librarys.worker = require("lworker")
    --unqlite
    librarys.unqlite = require("lunqlite")
    --sqlite
    librarys.sqlite = require("lsqlite")
    --lmdb
    librarys.lmdb = require("lmdb")
end

--index
local function _glib_index(o, k)
    local v = rawget(o, k)
    if v then
        return v
    end
    return librarys[k]
end

--newindex
local function _glib_newindex(o, k, v)
    if librarys[k] then
        logger.warn("[quanta][library] try modify quanta library [{}] namespace", k)
        return
    end
    rawset(o, k, v)
end

--设置元表不能修改
setmetatable(_G, { __index = _glib_index, __newindex = _glib_newindex })
