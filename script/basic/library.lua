--library.lua
local sformat   = string.format
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
    protobuf = require("pb"),
    --json库
    json = require("ljson"),
    --bson库
    bson = require("lbson"),
    --编码库
    codec = require("lcodec"),
    --加密解密库
    crypt = require("lcrypt"),
}

--特定模块
if qgetenv("QUANTA_MODE") then
    --aoi解析
    librarys.aoi = require("laoi")
    --http解析
    librarys.http = require("lhttp")
    --Curl库
    librarys.curl = require("lcurl")
    --网络库
    librarys.luabus = require("luabus")
    --detour库
    librarys.detour = require("ldetour")
    --多线程库
    librarys.worker = require("lworker")
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
        log.warn(sformat("[quanta][library] try modify quanta library [%s] namespace", k))
        return
    end
    rawset(o, k, v)
end

--设置元表不能修改
setmetatable(_G, { __index = _glib_index, __newindex = _glib_newindex })
