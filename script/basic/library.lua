--library.lua
local sformat   = string.format

--加载全局扩展库，使用顶级域名
local librarys = {
    --aoi解析
    aoi = require("laoi"),
    --日志库
    log = require("lualog"),
    --http解析
    http = require("lhttp"),
    --Curl库
    curl = require("lcurl"),
    --json库
    json = require("lcjson"),
    --加密解密库
    crypt = require("lcrypt"),
    --编码库
    codec = require("lcodec"),
    --文件系统库
    stdfs = require("lstdfs"),
    --定时器库
    timer = require("ltimer"),
    --PB解析库
    protobuf = require("pb"),
    --网络库
    luabus = require("luabus"),
    --Mongo驱动/bson库
    mongo = require("lmongo"),
    --detour库
    detour = require("ldetour"),
    --多线程库
    worker = require("lworker"),
}

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
