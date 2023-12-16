
local log_debug     = logger.debug
local mrandom       = qmath.random

local SUCCESS       = quanta.enum("KernCode", "SUCCESS")

local mongo_mgr     = quanta.get("mongo_mgr")

local AccordDao = singleton()
function AccordDao:__init()
end

-- 加载数据
function AccordDao:load_data(document)
    local code, data = mongo_mgr:find(mrandom(), document, {})
    if code ~= SUCCESS then
        log_debug("[AccordDao][load_data] document:{} code:{}", document, code)
        return false, code
    end
    return true, data
end

-- 插入数据
function AccordDao:insert(document, data)
    local code = mongo_mgr:insert(mrandom(), document, data)
    if code ~= SUCCESS then
        log_debug("[AccordDao][insert] document:{} code:{}", document, code)
        return false
    end
    return true
end

-- 更新数据
function AccordDao:update(document, data)
    local udata = { ["$set"] = data }
    local code = mongo_mgr:update(1, mrandom(), document, udata, { id = data.id })
    if code ~= SUCCESS then
        log_debug("[AccordDao][update] document:{} code:{}", document, code)
        return false
    end
    return true
end

-- 删除数据
function AccordDao:delete(document, id)
    local code = mongo_mgr:delete(1, mrandom(), document, {id=id})
    if code ~= SUCCESS then
        log_debug("[AccordDao][delete] document:{} code:{}", document, code)
        return false
    end
    return true
end

quanta.accord_dao = AccordDao()
return AccordDao
