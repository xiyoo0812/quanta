
local log_err       = logger.err
local mrandom       = qmath.random

local SUCCESS       = quanta.enum("KernCode", "SUCCESS")

local mongo_mgr     = quanta.get("mongo_mgr")

local AccordDao = singleton()
function AccordDao:__init()
end

-- 加载协议配置
function AccordDao:load_accord_conf()
    local code, data = mongo_mgr:find(1, mrandom(), "accord_conf", {})
    if code ~= SUCCESS then
        return false, code
    end
    return true, data
end

-- 添加协议配置
function AccordDao:add_accord_conf(data)
    local code, res = mongo_mgr:insert(1, mrandom(), "accord_conf", data,nil)
    if code ~= SUCCESS then
        log_err("[AccordDao][add_accord_conf] name:%s", data.name, code, res)
        return false
    end
    return true
end

-- 存储协议配置
function AccordDao:save_accord_conf(data)
    local udata = { ["$set"] = data }
    local code, res = mongo_mgr:update(1, mrandom(), "accord_conf", udata, { name = data.name })
    if code ~= SUCCESS then
        log_err("[AccordDao][save_accord_conf] name:%s", data.name, code, res)
        return false
    end
    return true
end

-- 删除协议配置
function AccordDao:del_accord_conf(name)
    local code, res = mongo_mgr:delete(1, mrandom(), "accord_conf", { name = name })
    if code ~= SUCCESS then
        log_err("[AccordDao][del_accord_conf] name:%s", name, code, res)
        return false
    end
    return true
end

-- 加载服务器配置
function AccordDao:load_server_list()
    local code, data = mongo_mgr:find(1, mrandom(), "accord_server", {})
    if code ~= SUCCESS then
        return false, code
    end
    return true, data
end

-- 添加服务配置
function AccordDao:add_server(data)
    local code, res = mongo_mgr:insert(1, mrandom(), "accord_server", data)
    if code ~= SUCCESS then
        log_err("[AccordDao][add_server] name:%s", data.name, code, res)
        return false
    end
    return true
end

-- 保存服务配置
function AccordDao:save_server(data)
    local udata = { ["$set"] = data }
    local code, res = mongo_mgr:update(1, mrandom(), "accord_server", udata, { name = data.name })
    if code ~= SUCCESS then
        log_err("[AccordDao][save_server] name:%s", data.name, code, res)
        return false
    end
    return true
end

-- 删除服务配置
function AccordDao:del_server(name)
    local code, res = mongo_mgr:delete(1, mrandom(), "accord_server", { name = name })
    if code ~= SUCCESS then
        log_err("[AccordDao][del_server] name:%s", name, code, res)
        return false
    end
    return true
end

quanta.accord_dao = AccordDao()
return AccordDao
