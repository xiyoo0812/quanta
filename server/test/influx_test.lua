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
    local _orgs = influx:find_org()
    log_debug("find_org: %s", _orgs)
    local bucket = influx:create_bucket("testdb")
    log_debug("create_bucket: %s", bucket)
    local _bucket = influx:find_bucket("testdb")
    log_debug("find_bucket: %s", _bucket)
    local res = influx:delete_bucket_by_id(_bucket.id)
    log_debug("delete_bucket_by_id: %s", res)
    local bucket2 = influx:create_bucket("testdb")
    log_debug("create_bucket: %s", bucket2)
    local wres = influx:write("test_tab", {type = 3}, {id = 5, name = "3333", exp = 666})
    log_debug("write: %s", wres)
    local wres = influx:query([[from(bucket: "testdb")
    |> range(start: -12h)
    |> filter(fn: (r) => r["_measurement"] == "test_tab")
    |> filter(fn: (r) => r["_field"] == "exp" or r["_field"] == "id")
    |> filter(fn: (r) => r["type"] == "3")
    |> aggregateWindow(every: 1h, fn: mean, createEmpty: false)
    |> yield(name: "mean")]])
    log_debug("query: %s", wres)
end)
