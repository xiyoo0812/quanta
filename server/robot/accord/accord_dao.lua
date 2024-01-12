
local log_err       = logger.err
local jdecode       = json.decode
local sformat       = string.format

local ACCORD_URL    = environ.get("QUANTA_ACCORD_URL")

local http_client   = quanta.get("http_client")

local AccordDao = singleton()
function AccordDao:__init()
end

-- 加载数据
function AccordDao:load_data(document)
    local url = sformat("%s/accord_data/load_data", ACCORD_URL)
    local ok, status, body = http_client:call_get(url, { tab = document })
    if not ok or status ~= 200 then
        log_err("[AccordDao][load_data] url:{}", url)
        return false, nil
    end
    local data = jdecode(body)
    if type(data) == "table" then
        return ok, data.data or {}
    end
    return ok, { }
end

-- 插入数据
function AccordDao:insert(document, data)
    local headers = {
        ["Content-type"] = "application/json"
    }
    local request = {
        tab = document,
        data = data
    }
    local url = sformat("%s/accord_data/insert", ACCORD_URL)
    local ok, status = http_client:call_post(url, request, headers)
    if not ok or status ~= 200 then
        return false
    end
    return ok
end

-- 更新数据
function AccordDao:update(document, data)
    local headers = {
        ["Content-type"] = "application/json"
    }
    local request = {
        id = data.id,
        tab = document,
        data = data
    }
    request.data.id = nil
    local url = sformat("%s/accord_data/update", ACCORD_URL)
    local ok, status, _ = http_client:call_post(url, request, headers)
    return ok and status == 200
end

-- 删除数据
function AccordDao:delete(document, id)
    local query = {
        id = id,
        tab = document
    }
    local url = sformat("%s/accord_data/delete", ACCORD_URL)
    local ok, status, _ = http_client:call_get(url, query)
    return ok and status == 200
end

quanta.accord_dao = AccordDao()
return AccordDao
