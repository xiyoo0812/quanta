-- netlog_mgr.lua
local next          = next
local otime         = os.time
local log_debug     = logger.debug
local tinsert       = table.insert
local ssplit        = string_ext.split
local serialize     = logger.serialize

local event_mgr     = quanta.get("event_mgr")
local timer_mgr     = quanta.get("timer_mgr")

local PeriodTime    = enum("PeriodTime")

local PULL_CNT_MAX  = 10

local NetlogMgr = singleton()
function NetlogMgr:__init()
    self.sessions = {}
    self:setup()
end

function NetlogMgr:setup()
    event_mgr:add_listener(self, "rpc_pull_log")
    event_mgr:add_listener(self, "rpc_query_log")
    event_mgr:add_listener(self, "rpc_close_log")

    timer_mgr:loop(PeriodTime.SECOND_MS, function()
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
        event_mgr:remove_trigger(self, "on_log_output")
    end
end

function NetlogMgr:on_log_output(log_context)
    for _, session in pairs(self.sessions) do
        tinsert(session.cache_logs, log_context)
    end
end

function NetlogMgr:rpc_query_log(data)
    log_debug("[NetlogMgr][rpc_query_log]->data:%s", serialize(data))
    local session_id, context = data.session_id, data.context
    if not session_id then
        return { code = 1, msg= "param errror!" }
    end
    if not context or context == "" then
        return { code = 1, msg = "filter words empty!" }
    end
    if not next(self.sessions) then
        event_mgr:add_trigger(self, "on_log_output")
    end
    local session = self.sessions[session_id]
    if not session then
        session = self:open_session(session_id)
    end
    session.filters = ssplit(data.context, ",")
    return { name = "rpc_query_log", code = 0, session_id = session_id }
end

function NetlogMgr:rpc_pull_log(data)
    local session_id = data.session_id
    local session = self.sessions[session_id]
    if not session then
        return {name = "rpc_pull_log", code = 1, msg = "find agent failed!"}
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
    return {name = "rpc_pull_log", code = 0, session_id = session_id,  logs = pull_logs}
end

function NetlogMgr:rpc_close_log(data)
    log_debug("[NetlogMgr][rpc_close_log]->data", serialize(data))
    local session_id = data.session_id
    if not session_id then
        return { name = "rpc_close_log", code = 1, msg = "session id empty!" }
    end
    self:close_session(session_id)
    return { name = "rpc_close_log", code = 0 }
end

function NetlogMgr:on_timer()
    local overdue = {}
    local cur_time = otime()
    for session_id, session in pairs(self.sessions) do
        if cur_time - session.active_time > PeriodTime.SECOND_10_MS then
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
