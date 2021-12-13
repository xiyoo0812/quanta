-- netlog_mgr.lua
local tinsert       = table.insert
local log_debug     = logger.debug
local setup_monitor = logger.setup_monitor
local sfind         = string.find
local sformat       = string.format
local ssplit        = string_ext.split

local event_mgr     = quanta.get("event_mgr")
local timer_mgr     = quanta.get("timer_mgr")

local PeriodTime    = enum("PeriodTime")

local PULL_CNT_MAX  = 10

local NetlogMgr = singleton()
local prop = property(NetlogMgr)
prop:reader("sessions", {})
function NetlogMgr:__init()
    event_mgr:add_listener(self, "rpc_show_log")
    timer_mgr:loop(PeriodTime.SECOND_MS, function()
        self:on_timer()
    end)
end

function NetlogMgr:open_session(data)
    local session_id = data.session_id
    local session = self.sessions[session_id]
    if not session then
        session = {
            pull_index  = 0,
            cache_logs  = {},
            filters     = {},
        }
        self.sessions[session_id] = session
    end
    if data.filters then
        session.filters = ssplit(data.filters, ",")
    end
    session.active_time = quanta.now
    return session
end

function NetlogMgr:close_session(session_id)
    self.sessions[session_id] = nil
    if not next(self.sessions) then
        setup_monitor(nil)
    end
end

function NetlogMgr:notify(level, content)
    for _, session in pairs(self.sessions) do
        local hit_filter = false
        for _, filter in pairs(session.filters) do
            if sfind(content, filter) then
                hit_filter = true
                break
            end
        end
        if hit_filter then
            tinsert(session.cache_logs, sformat("[%s]%s", level, content))
        end
    end
end

function NetlogMgr:rpc_show_log(data)
    log_debug("[NetlogMgr][rpc_show_log]->data:%s", data)
    local session_id = data.session_id
    if not session_id then
        return { code = 1, msg= "param errror!" }
    end
    if not next(self.sessions) then
        setup_monitor(self)
    end
    local show_logs = {}
    local session = self:open_session(data)
    local log_size = #(session.cache_logs)
    local log_cnt = log_size - session.pull_index
    if log_cnt > 0 then
        local count = log_cnt > PULL_CNT_MAX and PULL_CNT_MAX or log_cnt
        for idx = 1, count do
            tinsert(show_logs, session.cache_logs[session.pull_index + idx])
        end
        session.pull_index = session.pull_index + count
        if session.pull_index >= log_size then
            session.cache_logs = {}
            session.pull_index = 0
        end
    end
    return { code = 0, msg = show_logs }
end

function NetlogMgr:on_timer()
    local cur_time = quanta.now
    for session_id, session in pairs(self.sessions) do
        if cur_time - session.active_time > PeriodTime.SECOND_10_MS then
            log_debug("[NetlogMgr][on_timer]->overdue->session_id:%s", session_id)
            self:close_session(session_id)
        end
    end
end

quanta.Netllog_mgr = NetlogMgr()

return NetlogMgr
