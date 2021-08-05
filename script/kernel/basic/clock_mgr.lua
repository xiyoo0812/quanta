--clock_mgr.lua
local lcrypt    = require("lcrypt")

local new_guid  = lcrypt.guid_new

local ClockMgr = singleton()
local prop = property(ClockMgr)
prop:reader("clocks", {})
function ClockMgr:__init()
end

function ClockMgr:trigger(clock_id, now_ms)
    local clock = self.clocks[clock_id]
    if clock then
        local period = clock.period
        local escape_ms = now_ms - clock.last_ms
        if now_ms - clock.last_ms >= period then
            local count = (now_ms - clock.start_ms) // period
            clock.last_ms = now_ms
            clock.count = count
            return escape_ms, count
        end
    end
end

function ClockMgr:watch(period, now_ms)
    --生成id并注册
    local clock_id = new_guid(period, period)
    self.clocks[clock_id] = {
        period = period,
        last_ms = now_ms,
        start_ms = now_ms,
        count = 0,
    }
    return clock_id
end

function ClockMgr:unregister(clock_id)
    self.clocks[clock_id] = nil
end

function ClockMgr:close()
    self.clocks = {}
end

quanta.clock_mgr = ClockMgr()

return ClockMgr
