-- accord_mgr.lua
import("robot/robot_mgr.lua")

local log_debug     = logger.debug
local sformat       = string.format

local HttpServer    = import("network/http_server.lua")

local scheduler     = quanta.get("scheduler")
local event_mgr     = quanta.get("event_mgr")

local AccordMgr = singleton()
local prop = property(AccordMgr)
prop:reader("http_server", nil)
prop:reader("workers", {})

function AccordMgr:__init()
    -- 创建HTTP服务器
    local server = HttpServer()
    server:listen(environ.addr("QUANTA_ACCORD_HTTP"))
    --启用跨域支持（供编辑器跨域调用）
    server:enable_cors()
    server:register_post("/case", "on_case", self)
    server:register_post("/node", "on_node", self)
    server:register_post("/stop", "on_stop", self)
    server:register_get("/status", "on_status", self)
    server:register_get("/message", "on_message", self)
    service.modify_host(server:get_port())
    self.http_server = server
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
        return thread_name
    end
end

-- http 回调
----------------------------------------------------------------------
-- 拉取日志
function AccordMgr:on_message(url, body, params)
    local open_id = params.open_id
    local thread_name = self:load_worker(open_id, false)
    if thread_name then
        local ok, messages = scheduler:call(thread_name, "fetch_robot_messages", open_id)
        if ok then
            return { code = 0, msg = messages }
        end
        return { code = -1, msg = "fetch robot messages failed" }
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
function AccordMgr:on_node(url, body, params)
    log_debug("[AccordMgr][on_node] params:{}, data:{}", params, body)
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
function AccordMgr:on_case(url, body, params)
    log_debug("[AccordMgr][on_case] params:{}, data:{}", params, body)
    local open_id, addr, port = params.open_id, params.addr, params.port
    local thread_name = self:load_worker(open_id, true)
    if thread_name then
        local ok, res = scheduler:call(thread_name, "run_robot_case", open_id, addr, port, body)
        if ok then
            return { code = res and 0 or -1, msg = res and "success" or "failed" }
        end
        return { code = -1, msg = res }
    end
    return { code = -1, msg = "robot worker not exist" }
end

-- 停止用例
function AccordMgr:on_stop(url, body, params)
    log_debug("[AccordMgr][on_stop] body:{}", body)
    local open_id = params.open_id
    local thread_name = self:load_worker(open_id, false)
    if thread_name then
        scheduler:call(thread_name, "stop_robot_case", open_id)
        event_mgr:fire_frame(function()
            self.workers[open_id] = nil
            scheduler:stop(thread_name)
        end)
    end
    return { code = -1, msg = "success" }
end

quanta.accord_mgr = AccordMgr()

return AccordMgr
