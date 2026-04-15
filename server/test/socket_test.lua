-- socket_test.lua
local log_debug    = logger.debug

local ping      = luabus.ping
local ip2region = luabus.ip2region("./data/ip2region_v4.xdb")

local ips = {
    "124.237.177.164",
    "123.150.76.218",
    "47.106.68.25",
    "121.14.77.201",
    "172.67.179.61",
    "150.171.28.10",
    "13.107.213.46",
    "106.81.36.132",
    "10.96.8.40"
}

local ip = luabus.dns("www.google.com")
log_debug("luabus dns-> {}", ip)

local ip1 = luabus.host()
log_debug("luabus host-> {}", ip1)

local ip = luabus.ipconfig()
log_debug("luabus ipconfig-> {}", ip)

for _, ip in ipairs(ips) do
    local ok, region = ip2region.search(ip)
    if not ok then
        log_debug("ip2region search {} error", ip)
    end
    local ping_time, succtime = ping(ip, 3)
    log_debug("ip2region search {} => {}, ping: {} =>{}", ip, region, ping_time, succtime)
end
