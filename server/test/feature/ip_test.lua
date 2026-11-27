-- ip_test.lua

local log_info  = logger.info
local sformat   = string.format

--覆盖国内/国际/内网地址
local IPS = {
    "124.237.177.164",   --国内
    "47.106.68.25",      --国内
    "172.67.179.61",     --国外
    "10.96.8.40",        --内网
}

local TestCase  = import("test/case.lua")
local IpTest    = class(TestCase)

function IpTest:run()
    ------------------------------------------------------------------
    --1. 基础接口: host / dns / ipconfig 应返回字符串
    ------------------------------------------------------------------
    local host = luabus.host()
    self:report("host returns string", type(host) == "string" and #host > 0, host, "non-empty string")

    local dns = luabus.dns("www.google.com")
    self:report("dns returns ip list", type(dns) == "table" and #dns > 0, dns, "non-empty table")

    local ipc = luabus.ipconfig()
    self:report("ipconfig returns table", type(ipc) == "table", type(ipc), "table")

    ------------------------------------------------------------------
    --2. ip2region: 加载数据库并按 IP 查询归属地
    ------------------------------------------------------------------
    local xdb = self.addr or "./data/ip2region_v4.xdb"
    local ip2region = luabus.ip2region(xdb)
    self:report("ip2region create", ip2region ~= nil, ip2region ~= nil, true)
    if not ip2region then return end

    for _, ip in ipairs(IPS) do
        local ok, region = ip2region.search(ip)
        self:report(sformat("ip2region.search(%s)", ip), ok == true and type(region) == "string",
            region, "string")
        if ok then
            log_info("[ip2region] {} => {}", ip, region)
        end
    end

    ------------------------------------------------------------------
    --3. 非法 IP: 查询应能处理(不抛异常)
    ------------------------------------------------------------------
    local ok_bad = pcall(function()
        return ip2region.search("not-an-ip")
    end)
    self:report("ip2region invalid ip no throw", ok_bad == true, ok_bad, true)
end

return IpTest
