-- influx_test.lua
local Influx    = import("driver/influx.lua")

local log_debug = logger.debug

local timer_mgr = quanta.get("timer_mgr")

local conf = {
    host = "9.134.163.87",
    port = 8086,
    user = "xiyoo0812",
    db = "testdb",
    passwd = "d5SUTYyl4jou8BNN4Ee2kn1U0IhWuj3P7qR7JDU_59e7UAzW0yQq_oCyLcHbFt7nX_45yYfDCsmF7beZd6LiSQ=="
}

local influx    = Influx()

timer_mgr:once(2000, function()
    influx:setup(conf)
    local bucket = influx:find_bucket("_tasks")
    log_debug("find_bucket: %s", bucket)
    local orgs = influx:find_org()
    log_debug("find_org: %s", orgs)
end)
