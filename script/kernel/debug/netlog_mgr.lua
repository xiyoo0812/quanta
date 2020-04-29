-- Netllog_mgr.lua
local NetlogAgent   = import("share/monitor/Netllog_agent.lua")
local next          = next
local otime         = os.time
local log_debug     = logger.debug
local ssplit        = string_ext.split
local serialize     = logger.serialize

local router_mgr    = quanta.router_mgr
local timer_mgr     = quanta.timer_mgr
local listener      = quanta.listener

local PULL_CNT_MAX  = 10
local TIMER_PERIOD  = 1000
local OVERDUE_TIME  = 10 * 1000

local NetlogMgr = singleton()

function NetlogMgr:__init()
    self.sessions = {}
    self:setup()
end

function NetlogMgr:setup()
    router_mgr:add_listener(self, "pull_log")
    router_mgr:add_listener(self, "query_log")
    router_mgr:add_listener(self, "close_log")

    timer_mgr:loop(TIMER_PERIOD, function()
        self:on_timer()
    end)
end

function NetlogMgr:open_session(session_id)
    local session = {
        active_time = 0,
        pull_index  = 0,
        cache_logs  = {},
        filters     = {},
    }
    self.sessions[session_id] = session
    return session
end

function NetlogMgr:close_session(session_id)
    self.sessions[session_id] = nil
    if not next(self.sessions) then
        listener:remove_trigger(self, "on_log_output")
    end
end

function NetlogMgr:on_log_output(log_context)
    for _, session in pairs(self.sessions) do
        tinsert(session.cache_logs, log_context)
    end
end

function NetlogMgr:query_log(json_data)
    log_debug("[NetlogMgr][query_log]->json_data:%s", serialize(json_data))
    local session_id, context = json_data.session, json_data.context
    if not session_id then
        return { code = 1, msg= "param errror!" }
    end
    if not context or context == "" then
        return { code = 1, msg = "filter words empty!" }
    end
    if not next(self.sessions) then
        listener:add_trigger(self, "on_log_output")
    end
    local session = self.sessions[session_id]
    if not session then
        session = self:open_session(session_id)
    end
    session.filters = ssplit(json_data.context, ",")
    return { name = "query_log", code = 0, session = session_id }
end

function NetlogMgr:pull_log(json_data)
    local session_id = json_data.session
    local session = self.sessions[session_id]
    if not session then
        return {name = "pull_log", code = 1, msg = "find agent failed!"}
    end
    local pull_logs = {}
    session.active_time = otime()
    if session.pull_index < session.log_index then
        local log_size = #session.cache_logs
        local log_cnt = log_size - session.pull_index
        local count = log_cnt > PULL_CNT_MAX and PULL_CNT_MAX or log_cnt
        for idx = 1, count do
            tinsert(pull_logs, session.cache_logs[session.pull_index + idx])
        end
        session.pull_index = session.pull_index + count
        if session.pull_index == log_size then
            session.cache_logs = {}
            session.pull_index = 0
        end
    end
    return {name = "pull_log", code = 0, session = session_id,  logs = pull_logs}
end

function NetlogMgr:close_log(json_data)
    log_debug("[NetlogMgr][pull_log]->json_data", serialize(json_data))
    local session_id = json_data.session
    if not session_id then
        return { name = "close_log", code = 1, msg = "session id empty!" }
    end
    self:close_session(session_id)
    return { name = "close_log", code = 0 }
end

function NetlogMgr:on_timer()
    local overdue = {}
    local cur_time = otime()
    for session_id, session in pairs(self.sessions) do
        if cur_time - session.active_time > OVERDUE_TIME then
            overdue[session_id] = 1
        end
    end
    for session_id in pairs(overdue) do
        log_debug("[NetlogMgr][on_timer]->overdue->session_id:%s", session_id)
        self:close_session(session_id)
    end
end

quanta.Netllog_mgr = NetlogMgr()

return NetlogMgr
