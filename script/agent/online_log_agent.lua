-- online_log_agent.lua
local otime         = os.time
local sfind         = string.find
local tinsert       = table.insert
local log_debug     = logger.debug
local serialize     = logger.serialize

local MAX_LOGS      = 1000
local PER_CNT_MAX   = 10

local OnlineLogAgent = class()

function OnlineLogAgent:__init(session)
    self.session     = session

    self.cache_logs     = {}
    self.logs_index     = 0

    self.filters        = {}
    self.active_time    = 0

    self.pull_index     = 0
end

-- 开始订阅日志
function OnlineLogAgent:start()
    self.active_time = otime()
end

-- 筛选日志
function OnlineLogAgent:filter(key_words)
    log_debug("[OnlineLogAgent][filter]->key_words:%s", serialize(key_words))
    self.filters = key_words or {}
end

-- 拉取日志
function OnlineLogAgent:pull()
    local ret_logs = {}
    if self.pull_index < self.logs_index then
        -- 避免超过包大小,每次最大拉取PER_CNT_MAX条日志
        local count = (self.logs_index - self.pull_index > PER_CNT_MAX) and PER_CNT_MAX or (self.logs_index - self.pull_index)
        for idx = 1, count do
            tinsert(ret_logs, self.cache_logs[self.pull_index + idx])
        end
    end
    self.active_time = otime()
    return ret_logs
end

-- 订阅日志
function OnlineLogAgent:add_log(line)
    if not next(self.filters) then
        return
    end

    for filter_word in pairs(self.filters) do
        if sfind(line, filter_word, 1, true) then
            -- 日志条数超过MAX_LOGS进行裁剪
            if self.logs_index > MAX_LOGS then
                self.cache_logs[self.logs_index-MAX_LOGS] = nil
            end

            self.cache_logs[self.logs_index] = line
            self.logs_index = self.logs_index + 1
            break
        end
    end
end

return OnlineLogAgent
