-- redis_clu_test.lua
local sformat       = string.format

local redis_mgr     = quanta.load("redis_mgr")
local thread_mgr    = quanta.get("thread_mgr")
local PREFIX        = "rc:"

local TestCase      = import("test/case.lua")
local RedisCluTest  = class(TestCase)

function RedisCluTest:setup()
    quanta.setenv("QUANTA_REDIS_URL", self.addr)
    import("db/redis_mgr.lua")
    redis_mgr = quanta.get("redis_mgr")
    thread_mgr:sleep(2000)
end

function RedisCluTest:on_cleanup()
    local keys = {
        "rc:k1", "rc:k2", "rc:k3", "rc:k4", "rc:cnt", "rc:h1", "rc:l1",
        "rc:set1", "rc:z1", "rc:ttl", "rc:tag{a}1", "rc:tag{a}2", "rc:{a}k1", "rc:{a}k2",
    }
    redis_mgr:execute("del", table.unpack(keys))
end

function RedisCluTest:run()
    local function exec(cmd, ...)
        local code, res = redis_mgr:execute(cmd, ...)
        return code == 0, res
    end
    local function scanall(pattern)
        local cursor, found, guard = "0", {}, 0
        repeat
            local code, c, rows = redis_mgr:execute("scan", cursor, "match", pattern, "count", 100)
            if code ~= 0 then
                break
            end
            cursor = c
            if type(rows) == "table" then
                for _, k in ipairs(rows) do
                    found[k] = true
                end
            end
            guard = guard + 1
        until cursor == "0" or cursor == 0 or guard > 1000
        return found
    end

    local rdb = redis_mgr.redis_db

    ------------------------------------------------------------------
    --1. 连接状态与 cluster 标志
    ------------------------------------------------------------------
    local available = rdb and rdb:available() or false
    self:report("redis connected", available == true, available, "not connected")
    local cluster_mode = rdb and rdb.cluster == true
    self:report("cluster flag readable", cluster_mode == true or cluster_mode == false,
        sformat("cluster={}", tostring(cluster_mode)), "expected boolean")

    ------------------------------------------------------------------
    --2. cluster 拓扑命令(仅 cluster 模式下断言; 单机 Redis 不支持, 属预期)
    ------------------------------------------------------------------
    if cluster_mode then
        local ok, res = exec("cluster", "slots")
        self:report("cluster slots", ok and type(res) == "table" and #res > 0, res, res)
        ok, res = exec("cluster", "info")
        self:report("cluster info", ok and type(res) == "string", res, res)
        ok, res = exec("cluster", "nodes")
        self:report("cluster nodes", ok and type(res) == "string" and #res > 0, res, res)
        self:report("cluster slots loaded", rdb and #rdb.slots > 0, rdb and #rdb.slots, "slots empty")
    end

    ------------------------------------------------------------------
    --3. 跨 slot 的 string 读写(不同 key 触发不同节点路由)
    ------------------------------------------------------------------
    local ok, res = exec("set", PREFIX .. "k1", "v1")
    self:report("set rc:k1", ok, res, res)
    ok, res = exec("set", PREFIX .. "k2", "v2")
    self:report("set rc:k2", ok, res, res)
    ok, res = exec("get", PREFIX .. "k1")
    self:report("get rc:k1", ok and res == "v1", res, res)
    ok, res = exec("get", PREFIX .. "k2")
    self:report("get rc:k2", ok and res == "v2", res, res)

    ------------------------------------------------------------------
    --4. 批量 mset/mget(跨 slot 多键)
    ------------------------------------------------------------------
    ok, res = exec("mset", PREFIX .. "k3", "v3", PREFIX .. "k4", "v4")
    self:report("mset k3/k4", ok, res, res)
    local mcode, mres = redis_mgr:execute("mget", PREFIX .. "k3", PREFIX .. "k4")
    self:report("mget k3/k4", mcode == 0 and type(mres) == "table" and mres[1] == "v3" and mres[2] == "v4", mres, mres)

    ------------------------------------------------------------------
    --5. hash tag: 相同 tag 的 key 落同一槽, 批量操作可用
    ------------------------------------------------------------------
    ok, res = exec("mset", PREFIX .. "tag{a}1", "a1", PREFIX .. "tag{a}2", "a2")
    self:report("mset hash-tag keys", ok, res, res)
    mcode, mres = redis_mgr:execute("mget", PREFIX .. "tag{a}1", PREFIX .. "tag{a}2")
    self:report("mget hash-tag keys", mcode == 0 and mres[1] == "a1" and mres[2] == "a2", mres, mres)

    ------------------------------------------------------------------
    --6. incr(分布式自增 key)
    ------------------------------------------------------------------
    ok, res = exec("del", PREFIX .. "cnt")
    self:report("del rc:cnt", ok, res, res)
    ok, res = exec("incr", PREFIX .. "cnt")
    self:report("incr rc:cnt =1", ok and tonumber(res) == 1, res, res)
    ok, res = exec("incrby", PREFIX .. "cnt", 9)
    self:report("incrby rc:cnt =10", ok and tonumber(res) == 10, res, res)

    ------------------------------------------------------------------
    --7. 其他数据类型按 key 分片
    ------------------------------------------------------------------
    ok, res = exec("hset", PREFIX .. "h1", "f1", "v1", "f2", "v2")
    self:report("hset rc:h1", ok, res, res)
    ok, res = exec("hget", PREFIX .. "h1", "f1")
    self:report("hget rc:h1", ok and res == "v1", res, res)

    ok, res = exec("rpush", PREFIX .. "l1", "a", "b", "c")
    self:report("rpush rc:l1", ok, tonumber(res) == 3, res)
    ok, res = exec("llen", PREFIX .. "l1")
    self:report("llen rc:l1", ok and tonumber(res) == 3, res, res)

    ok, res = exec("sadd", PREFIX .. "set1", "a", "b", "c")
    self:report("sadd rc:set1", ok and tonumber(res) == 3, res, res)
    ok, res = exec("scard", PREFIX .. "set1")
    self:report("scard rc:set1", ok and tonumber(res) == 3, res, res)

    ok, res = exec("zadd", PREFIX .. "z1", 1, "one", 2, "two")
    self:report("zadd rc:z1", ok and tonumber(res) == 2, res, res)
    ok, res = exec("zcard", PREFIX .. "z1")
    self:report("zcard rc:z1", ok and tonumber(res) == 2, res, res)

    ------------------------------------------------------------------
    --8. expire/ttl 与 persist
    ------------------------------------------------------------------
    ok, res = exec("expire", PREFIX .. "k1", 60)
    self:report("expire rc:k1", ok and tonumber(res) >= 1, res, res)
    ok, res = exec("ttl", PREFIX .. "k1")
    self:report("ttl rc:k1 > 0", ok and tonumber(res) > 0, res, res)
    ok, res = exec("persist", PREFIX .. "k1")
    self:report("persist rc:k1", ok and tonumber(res) >= 1, res, res)

    ------------------------------------------------------------------
    --9. scan 游标遍历(验证多返回值透传)
    ------------------------------------------------------------------
    local found, total = scanall(PREFIX .. "*"), 0
    for _ in pairs(found) do total = total + 1 end
    self:report("scan found written keys", found[PREFIX .. "k1"] == true and found[PREFIX .. "k2"] == true
        and found[PREFIX .. "h1"] == true, sformat("found={}", total), found)
end

return RedisCluTest
