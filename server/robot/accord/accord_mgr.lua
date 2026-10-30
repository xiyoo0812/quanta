-- accord_mgr.lua
import("robot/robot_mgr.lua")

local iopen         = io.open
local fstem         = stdfs.stem
local fremove       = stdfs.remove
local ssub          = string.sub
local supper        = string.upper
local ssplit        = string.split
local sformat       = string.format
local tunpack       = table.unpack
local log_debug     = logger.debug
local penum         = protobuf.enum
local pfields       = protobuf.fields

local field_type = {
    [1] =  "double",
    [2] =  "float",
    [3] =  "int64/sint64",
    [4] =  "uint64",
    [5] =  "int32/sint32",
    [6] =  "fixed64",
    [7] =  "fixed32",
    [8] =  "bool",
    [9] =  "string",
    [10] =  "group",
    [11] =  "message",
    [12] =  "bytes",
    [13] =  "uint32",
    [14] =  "enum",
    [15] =  "sfixed32",
    [16] =  "sfixed64",
    [17] =  "sint32",
    [18] =  "sint64"
}

local scheduler     = quanta.get("scheduler")
local event_mgr     = quanta.get("event_mgr")

local HttpServer    = import("network/http_server.lua")

local AccordMgr = singleton()
local prop = property(AccordMgr)
prop:reader("http_server", nil)
prop:reader("workers", {})
prop:reader("protos", {})
prop:reader("cases", {})

function AccordMgr:__init()
    -- 创建HTTP服务器
    local server = HttpServer()
    server:listen(environ.addr("QUANTA_ACCORD_HTTP"))
    server:register_get("/", "on_page", self)
    server:register_get("/logs", "on_logs", self)
    server:register_get("/cases", "on_cases", self)
    server:register_get("/protos", "on_protos", self)
    server:register_get("/status", "on_status", self)
    server:register_get("/message", "on_message", self)
    server:register_post("/case", "do_case", self)
    server:register_post("/node", "do_node", self)
    server:register_post("/stop", "do_stop", self)
    server:register_post("/cases", "do_cases", self)
    server:register_del("/cases", "del_cases", self)
    service.modify_host(server:get_port())
    self.http_server = server
    -- 加载协议和用例
    self:load_protos()
    self:load_cases()
end

-- 初始化协议数据
function AccordMgr:load_protos()
    local messages = protobuf.messages()
    for full_name, proto_name in pairs(messages) do
        local package_name = tunpack(ssplit(full_name, "."))
        local enum_type = package_name .. ".NCmdId"
        local msg_name = "NID_" .. supper(proto_name)
        local msg_id = penum(enum_type, msg_name)
        if msg_id then
            local values = {}
            local fields = pfields(full_name)
            for name, type in pairs(fields) do
                values[name] = field_type[type]
            end
            self.protos[msg_name] = {
                msg_id = msg_id,
                name = msg_name,
                fields = values,
                type = ssub(proto_name, -3)
            }
        end
    end
end

function AccordMgr:load_cases()
    local cur_dirs = stdfs.dir("./cases/")
    if not cur_dirs then
        stdfs.mkdir("./cases/")
        return
    end
    for _, file in pairs(cur_dirs) do
        if file.type == "regular" then
            local cfile = iopen(file.name, "rb")
            if cfile then
                local name = fstem(file.name)
                local content = cfile:read("*a")
                self.cases[name] = content
                cfile:close()
            end
        end
    end
end

function AccordMgr:load_worker(open_id, create)
    local thread_name = self.workers[open_id]
    if thread_name then
        return thread_name
    end
    if create then
        thread_name = sformat("robot_worker_%s", open_id)
        scheduler:startup(thread_name, "robot.worker.robot")
        self.workers[open_id] = thread_name
        -- 同步用例到worker
        for name, case in pairs(self.cases) do
            scheduler:call(thread_name, "update_case", case)
        end
        return thread_name
    end
end

-- http 回调
----------------------------------------------------------------------
---首页
function AccordMgr:on_page(url, body, params)
    local html = "<html><head><meta charset=\"utf-8\"><title>Quanta Accord</title></head><body>"
    local hfile = iopen("../tools/robot/editor.html", "rb")
    if hfile then
        html = hfile:read("*a")
        hfile:close()
    end
    return html
end

---获取所有用例
function AccordMgr:on_cases(url, body, params)
    return { code = 0, msg = self.cases }
end

--获取所有协议
function AccordMgr:on_protos(url, body, params)
    return { code = 0, msg = self.protos }
end

-- 拉取日志
function AccordMgr:on_message(url, body, params)
    local open_id = params.open_id
    local thread_name = self:load_worker(open_id)
    if thread_name then
        local ok, messages = scheduler:call(thread_name, "fetch_robot_messages", open_id)
        if ok then
            return { code = 0, msg = messages }
        end
        return { code = -1, msg = "fetch robot messages failed" }
    end
    return { code = -1, msg = "robot worker not exist" }
end

-- 拉取日志
function AccordMgr:on_logs(url, body, params)
    local open_id = params.open_id
    local thread_name = self:load_worker(open_id)
    if thread_name then
        local ok, logs = scheduler:call(thread_name, "fetch_robot_logs", open_id)
        if ok then
            return { code = 0, msg = logs }
        end
        return { code = -1, msg = "fetch robot logs failed" }
    end
    return { code = -1, msg = "robot worker not exist" }
end

-- 拉取状态
function AccordMgr:on_status(url, body, params)
    local open_id = params.open_id
    local thread_name = self:load_worker(open_id, false)
    if thread_name then
        local ok, status = scheduler:call(thread_name, "fetch_robot_states", open_id)
        if ok then
            return { code = 0, msg = status }
        end
        return { code = -1, msg = "fetch robot status failed" }
    end
    return { code = -1, msg = "robot worker not exist" }
end

-- 执行节点
function AccordMgr:do_node(url, body, params)
    log_debug("[AccordMgr][do_node] params:{}, data:{}", params, body)
    local open_id = params.open_id
    local thread_name = self:load_worker(open_id, false)
    if thread_name then
        local ok, res = scheduler:call(thread_name, "run_robot_node", open_id, body)
        if ok then
            return { code = res and 0 or -1, msg = res and "success" or "failed" }
        end
        return { code = -1, msg = res }
    end
    return { code = -1, msg = "robot worker not exist" }
end

-- 执行用例
function AccordMgr:do_case(url, body, params)
    log_debug("[AccordMgr][do_case] params:{}, data:{}", params, body)
    local open_id = params.open_id
    local thread_name = self:load_worker(open_id, true)
    if thread_name then
        local debug = params.debug == "1"
        local interval = tonumber(params.interval) or 1000
        local case = { name = body.name, root = body.root, nodes = body.nodes }
        local ok, res = scheduler:call(thread_name, "run_robot_case", open_id, body.params, case, interval, debug)
        if ok then
            return { code = res and 0 or -1, msg = res and "success" or "failed" }
        end
        return { code = -1, msg = res }
    end
    return { code = -1, msg = "robot worker not exist" }
end

-- 停止用例
function AccordMgr:do_stop(url, body, params)
    log_debug("[AccordMgr][do_stop] body:{}", body)
    local open_id = params.open_id
    local thread_name = self:load_worker(open_id, false)
    if thread_name then
        scheduler:call(thread_name, "stop_robot_case", open_id)
        event_mgr:fire_frame(function()
            scheduler:shutdown(thread_name)
            self.workers[open_id] = nil
        end)
    end
    return { code = -1, msg = "success" }
end

-- 保存用例
function AccordMgr:do_cases(url, body, params)
    log_debug("[AccordMgr][do_cases] params:{}", params)
    local file = iopen("./cases/" .. params.name .. ".json", "wb")
    if file then
        scheduler:broadcast("update_case", body)
        self.cases[params.name] = body
        file:write(body)
        file:close()
    end
    return { code = 0, msg = "success" }
end

-- 删除用例
function AccordMgr:del_cases(url, body, params)
    log_debug("[AccordMgr][del_cases] params:{}", params)
    self.cases[params.name] = nil
    scheduler:broadcast("delete_case", params.name)
    fremove("./cases/" .. params.name .. ".json")
    return { code = 0, msg = "success" }
end

quanta.accord_mgr = AccordMgr()

return AccordMgr
