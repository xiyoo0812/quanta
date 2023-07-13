import("agent/mongo_agent.lua")

local log_err       = logger.err
local qfailed       = quanta.failed

local mongo_agent   = quanta.get("mongo_agent")
local AccordDao      = singleton()
function AccordDao:__init()
end

-- 加载协议配置
function AccordDao:load_accord_conf()
    local ok, code, data = mongo_agent:find({ "accord_conf", {} }, nil)
    if not ok or qfailed(code) then
        return false, code
    end
    return ok, data
end

-- 添加协议配置
function AccordDao:add_accord_conf(data)
    local ok, code, res = mongo_agent:insert({ "accord_conf", data},nil)
    if qfailed(code, ok) then
        log_err("[AccordDao][add_accord_conf] name:%s", data.name, code, res)
        return false
    end
    return true
end

-- 存储协议配置
function AccordDao:save_accord_conf(data)
    local udata = { ["$set"] = data }
    local ok, code, res = mongo_agent:update({ "accord_conf", udata, { name = data.name } })
    if qfailed(code, ok) then
        log_err("[AccordDao][save_accord_conf] name:%s", data.name, code, res)
        return false
    end
    return true
end

-- 删除协议配置
function AccordDao:del_accord_conf(name)
    local ok, code, res = mongo_agent:delete({ "accord_conf", { name = name }},nil)
    if qfailed(code, ok) then
        log_err("[AccordDao][del_accord_conf] name:%s", name, code, res)
        return false
    end
    return true
end

-- 加载服务器配置
function AccordDao:load_server_list()
    local ok, code, data = mongo_agent:find({ "accord_server", {} }, nil)
    if not ok or qfailed(code) then
        return false, code
    end
    return ok, data
end

-- 添加服务配置
function AccordDao:add_server(data)
    local ok, code, res = mongo_agent:insert({ "accord_server", data},nil)
    if qfailed(code, ok) then
        log_err("[AccordDao][add_server] name:%s", data.name, code, res)
        return false
    end
    return true
end

-- 保存服务配置
function AccordDao:save_server(data)
    local udata = { ["$set"] = data }
    local ok, code, res = mongo_agent:update({ "accord_server", udata, { name = data.name } })
    if qfailed(code, ok) then
        log_err("[AccordDao][save_server] name:%s", data.name, code, res)
        return false
    end
    return true
end

-- 删除服务配置
function AccordDao:del_server(name)
    local ok, code, res = mongo_agent:delete({ "accord_server", { name = name }},nil)
    if qfailed(code, ok) then
        log_err("[AccordDao][del_server] name:%s", name, code, res)
        return false
    end
    return true
end

quanta.accord_dao = AccordDao()
return AccordDao
