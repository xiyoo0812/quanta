-- redis_test.lua
import("db/redis_mgr.lua")

local sformat    = string.format

local thread_mgr = quanta.get("thread_mgr")
local redis_mgr  = quanta.get("redis_mgr")

local TestCase = import("test/case.lua")
local RedisTest = class(TestCase)

function RedisTest:setup()
    local deadline = quanta.clock_ms + 10000
    while quanta.clock_ms < deadline do
        local rdb = redis_mgr.redis_db
        if redis_mgr:available() and rdb and rdb.resp3 then
            return
        end
        thread_mgr:sleep(100)
    end
end

--兜底清理: 各段内的 del 属测试流程(验证命令本身), 这里统一清残留 key, 不计入断言
function RedisTest:teardown()
    local keys = {
        "rt:s1", "rt:cnt", "rt:h1", "rt:set1", "rt:z1", "rt:l1", "rt:hs1", "rt:json",
        "rt:m1", "rt:m2", "rt:m3", "rt:se", "rt:ap", "rt:sx", "rt:ib", "rt:gs",
        "rt:h2", "rt:l2", "rt:set2", "rt:set3", "rt:z2", "rt:type1", "rt:rn1", "rt:rn2",
    }
    redis_mgr:execute("del", table.unpack(keys))
end

function RedisTest:run()
    local function exec(cmd, ...)
        local code, res = redis_mgr:execute(cmd, ...)
        return code == 0, res
    end

    ------------------------------------------------------------------
    --0. RESP3 握手: 普通连接 login 时已发 HELLO 3
    ------------------------------------------------------------------
    local rdb = redis_mgr.redis_db
    self:report("resp3 handshake", rdb and rdb.resp3 == true, rdb and rdb.resp3, "fallback resp2?")

    ------------------------------------------------------------------
    --1. string: set/get/incr/del
    ------------------------------------------------------------------
    local ok, res = exec("set", "rt:s1", "hello")
    self:report("set rt:s1", ok, res, res)
    ok, res = exec("get", "rt:s1")
    self:report("get rt:s1", ok and res == "hello", res, res)
    ok, res = exec("incr", "rt:cnt")
    self:report("incr rt:cnt (integer)", ok and tonumber(res) ~= nil, res, res)
    ok, res = exec("del", "rt:s1", "rt:cnt")
    self:report("del string keys", ok, res, res)

    ------------------------------------------------------------------
    --2. hash: hset/hget/hgetall(验证 RESP3 map 幂等)/hexists(验证 bool)
    ------------------------------------------------------------------
    ok, res = exec("hset", "rt:h1", "f1", "v1", "f2", "v2")
    self:report("hset rt:h1", ok, res, res)
    ok, res = exec("hget", "rt:h1", "f1")
    self:report("hget rt:h1 f1", ok and res == "v1", res, res)
    ok, res = exec("hgetall", "rt:h1")
    self:report("hgetall rt:h1 (map)", ok and type(res) == "table" and res.f1 == "v1" and res.f2 == "v2", res, res)
    ok, res = exec("hexists", "rt:h1", "f1")
    self:report("hexists rt:h1 f1 (bool)", ok and res == true, res, res)
    ok, res = exec("hexists", "rt:h1", "nope")
    self:report("hexists missing (bool false)", ok and res == false, res, res)
    ok, res = exec("del", "rt:h1")
    self:report("del rt:h1", ok, res, res)

    ------------------------------------------------------------------
    --3. set: sadd/smembers/sismember(bool)/scard
    ------------------------------------------------------------------
    ok, res = exec("sadd", "rt:set1", "a", "b", "c")
    self:report("sadd rt:set1", ok, res, res)
    ok, res = exec("sismember", "rt:set1", "b")
    self:report("sismember b (bool true)", ok and res == true, res, res)
    ok, res = exec("sismember", "rt:set1", "z")
    self:report("sismember z (bool false)", ok and res == false, res, res)
    ok, res = exec("scard", "rt:set1")
    self:report("scard rt:set1", ok and tonumber(res) == 3, res, res)
    ok, res = exec("del", "rt:set1")
    self:report("del rt:set1", ok, res, res)

    ------------------------------------------------------------------
    --4. zset: zadd/zscore(incrbyfloat 验证 double)/zrange
    ------------------------------------------------------------------
    ok, res = exec("zadd", "rt:z1", 1, "one", 2, "two")
    self:report("zadd rt:z1", ok, res, res)
    ok, res = exec("zscore", "rt:z1", "two")
    self:report("zscore two (double)", ok and tonumber(res) == 2, res, res)
    ok, res = exec("zincrby", "rt:z1", 0.5, "two")
    self:report("zincrby two (double)", ok and tonumber(res) == 2.5, res, res)
    ok, res = exec("zrange", "rt:z1", 0, -1)
    self:report("zrange rt:z1", ok and type(res) == "table" and #res == 2, res, res)
    ok, res = exec("del", "rt:z1")
    self:report("del rt:z1", ok, res, res)

    ------------------------------------------------------------------
    --5. list: lpush/rpush/lrange
    ------------------------------------------------------------------
    ok, res = exec("rpush", "rt:l1", "a", "b", "c")
    self:report("rpush rt:l1", ok, res, res)
    ok, res = exec("lrange", "rt:l1", 0, -1)
    self:report("lrange rt:l1", ok and type(res) == "table" and res[1] == "a" and res[3] == "c", res, res)
    ok, res = exec("del", "rt:l1")
    self:report("del rt:l1", ok, res, res)

    ------------------------------------------------------------------
    --6. scan: hscan (cursor + kv)
    ------------------------------------------------------------------
    exec("hset", "rt:hs1", "k1", "v1", "k2", "v2")
    local scode, cur, vals = redis_mgr:execute("hscan", "rt:hs1", 0)
    self:report("hscan rt:hs1", scode == 0 and tonumber(cur) == 0 and type(vals) == "table" and vals.k1 == "v1", vals, vals)
    exec("del", "rt:hs1")

    ------------------------------------------------------------------
    --7. JSON (需 RedisJSON 模块, 缺失则记录失败但不影响其他用例)
    ------------------------------------------------------------------
    ok, res = exec("JSON.SET", "rt:json", "$", { abc = 3, nested = { ddd = 4 } })
    self:report("JSON.SET rt:json", ok, res, res)
    ok, res = exec("JSON.GET", "rt:json")
    --codec 遇到以 '{' 开头的 blob string 会自动 jcodec 解码为 table
    self:report("JSON.GET rt:json", ok and type(res) == "table" and
        tonumber(res.abc) == 3 and type(res.nested) == "table" and tonumber(res.nested.ddd) == 4, res, res)
    exec("DEL", "rt:json")

    ------------------------------------------------------------------
    --8. pub/sub: 任意连接订阅, 验证 RESP3 push 通道(确认与message都走push)
    ------------------------------------------------------------------
    local got_channel, got_data = nil, nil
    ok, res = rdb:subscribe(function(channel, data)
        got_channel, got_data = channel, data
    end, "rt:ch1")
    self:report("subscribe rt:ch1", ok, res, res)
    thread_mgr:sleep(300)   --等subscribe确认push异步更新subscribes
    exec("publish", "rt:ch1", "pushmsg")
    thread_mgr:sleep(500)
    self:report("pub/sub push delivered", got_data == "pushmsg" and got_channel == "rt:ch1",
        sformat("ch=%s, data=%s", got_channel, got_data), "no push received")
    ok, res = rdb:unsubscribe("rt:ch1")
    self:report("unsubscribe rt:ch1", ok, res, res)

    ------------------------------------------------------------------
    --8b. psubscribe: 模式订阅的 pmessage 回调(实际channel + payload)
    ------------------------------------------------------------------
    local got_pch, got_pdata = nil, nil
    ok, res = rdb:psubscribe(function(channel, data)
        got_pch, got_pdata = channel, data
    end, "rt:pat:*")
    self:report("psubscribe rt:pat:*", ok, res, res)
    thread_mgr:sleep(300)
    exec("publish", "rt:pat:one", "pm1")
    thread_mgr:sleep(500)
    self:report("pmessage push delivered", got_pch == "rt:pat:one" and got_pdata == "pm1",
        sformat("ch=%s, data=%s", got_pch, got_pdata), "no pmessage received")
    ok, res = rdb:punsubscribe("rt:pat:*")
    self:report("punsubscribe rt:pat:*", ok, res, res)

    ------------------------------------------------------------------
    --9. string 扩展: mset/mget/setex/ttl/append/strlen/setnx/incrby/getset
    ------------------------------------------------------------------
    ok, res = exec("mset", "rt:m1", "v1", "rt:m2", "v2", "rt:m3", "v3")
    self:report("mset 3 keys", ok, res, res)
    ok, res = exec("mget", "rt:m1", "rt:m2", "rt:m3")
    self:report("mget (v1,v2,v3)", ok and type(res) == "table" and res[1] == "v1" and res[2] == "v2" and res[3] == "v3", res, res)
    ok, res = exec("setex", "rt:se", 60, "tmp")
    self:report("setex", ok, res, res)
    ok, res = exec("ttl", "rt:se")
    self:report("ttl (expect > 0)", ok and tonumber(res) > 0 and tonumber(res) <= 60, res, res)
    ok, res = exec("append", "rt:ap", "ab")
    self:report("append (len=2)", ok and tonumber(res) == 2, res, res)
    ok, res = exec("append", "rt:ap", "cd")
    self:report("append again (len=4)", ok and tonumber(res) == 4, res, res)
    ok, res = exec("get", "rt:ap")
    self:report("verify append (abcd)", ok and res == "abcd", res, res)
    ok, res = exec("strlen", "rt:ap")
    self:report("strlen (expect 4)", ok and tonumber(res) == 4, res, res)
    ok, res = exec("setnx", "rt:sx", "1")
    self:report("setnx first (bool true)", ok and res == true, res, res)
    ok, res = exec("setnx", "rt:sx", "2")
    self:report("setnx again (bool false)", ok and res == false, res, res)
    ok, res = exec("incrby", "rt:ib", 10)
    self:report("incrby (+10)", ok and tonumber(res) == 10, res, res)
    ok, res = exec("decrby", "rt:ib", 3)
    self:report("decrby (-3 => 7)", ok and tonumber(res) == 7, res, res)
    ok, res = exec("getset", "rt:gs", "new")
    self:report("getset (first nil)", ok and res == nil, res, res)
    ok, res = exec("getset", "rt:gs", "newer")
    self:report("getset returns old (new)", ok and res == "new", res, res)

    ------------------------------------------------------------------
    --10. hash 扩展: hmget/hlen/hdel/hincrbyfloat/hkeys/hvals
    ------------------------------------------------------------------
    exec("hset", "rt:h2", "f1", "v1", "f2", "v2", "num", "10")
    ok, res = exec("hmget", "rt:h2", "f1", "f2", "nope")
    self:report("hmget (v1,v2,nil)", ok and type(res) == "table" and res[1] == "v1" and res[2] == "v2" and res[3] == nil, res, res)
    ok, res = exec("hlen", "rt:h2")
    self:report("hlen (expect 3)", ok and tonumber(res) == 3, res, res)
    ok, res = exec("hkeys", "rt:h2")
    self:report("hkeys (expect 3)", ok and type(res) == "table" and #res == 3, res, res)
    ok, res = exec("hvals", "rt:h2")
    self:report("hvals (expect 3)", ok and type(res) == "table" and #res == 3, res, res)
    ok, res = exec("hincrbyfloat", "rt:h2", "num", 0.5)
    self:report("hincrbyfloat (number)", ok and tonumber(res) == 10.5, res, res)
    ok, res = exec("hdel", "rt:h2", "f1")
    self:report("hdel (removed 1)", ok and tonumber(res) == 1, res, res)

    ------------------------------------------------------------------
    --11. list 扩展: lpush/llen/rpop/lpop/lset/ltrim
    ------------------------------------------------------------------
    ok, res = exec("lpush", "rt:l2", "b", "a")
    self:report("lpush (len=2)", ok and tonumber(res) == 2, res, res)
    ok, res = exec("llen", "rt:l2")
    self:report("llen (expect 2)", ok and tonumber(res) == 2, res, res)
    ok, res = exec("lrange", "rt:l2", 0, -1)
    self:report("lrange after lpush (a,b)", ok and res[1] == "a" and res[2] == "b", res, res)
    ok, res = exec("rpop", "rt:l2")
    self:report("rpop (expect b)", ok and res == "b", res, res)
    ok, res = exec("lpop", "rt:l2")
    self:report("lpop (expect a)", ok and res == "a", res, res)

    ------------------------------------------------------------------
    --12. set 扩展: smembers/srem/smove/sdiff/sinter/sunion
    ------------------------------------------------------------------
    exec("sadd", "rt:set2", "a", "b", "c")
    exec("sadd", "rt:set3", "b", "c", "d")
    ok, res = exec("smembers", "rt:set2")
    self:report("smembers (expect 3)", ok and type(res) == "table" and #res == 3, res, res)
    ok, res = exec("sinter", "rt:set2", "rt:set3")
    self:report("sinter (expect 2)", ok and type(res) == "table" and #res == 2, res, res)
    ok, res = exec("sunion", "rt:set2", "rt:set3")
    self:report("sunion (expect 4)", ok and type(res) == "table" and #res == 4, res, res)
    ok, res = exec("sdiff", "rt:set2", "rt:set3")
    self:report("sdiff (expect 1)", ok and type(res) == "table" and #res == 1, res, res)
    ok, res = exec("smove", "rt:set2", "rt:set3", "a")
    self:report("smove (bool true)", ok and res == true, res, res)

    ------------------------------------------------------------------
    --13. zset 扩展: zcard/zrank/zrangebyscore/zrem
    ------------------------------------------------------------------
    exec("zadd", "rt:z2", 1, "one", 2, "two", 3, "three")
    ok, res = exec("zcard", "rt:z2")
    self:report("zcard (expect 3)", ok and tonumber(res) == 3, res, res)
    ok, res = exec("zrank", "rt:z2", "two")
    self:report("zrank (expect 1)", ok and tonumber(res) == 1, res, res)
    ok, res = exec("zrangebyscore", "rt:z2", 2, 3)
    self:report("zrangebyscore (expect 2)", ok and type(res) == "table" and #res == 2, res, res)
    ok, res = exec("zrem", "rt:z2", "one")
    self:report("zrem (removed 1)", ok and tonumber(res) == 1, res, res)

    ------------------------------------------------------------------
    --14. key 管理: type/exists/rename/expire/persist/del
    ------------------------------------------------------------------
    exec("set", "rt:type1", "x")
    ok, res = exec("type", "rt:type1")
    self:report("type (string)", ok and res == "string", res, res)
    ok, res = exec("exists", "rt:type1")
    self:report("exists (bool true)", ok and res == true, res, res)
    ok, res = exec("expire", "rt:type1", 30)
    self:report("expire (bool true)", ok and res == true, res, res)
    ok, res = exec("persist", "rt:type1")
    self:report("persist (bool true)", ok and res == true, res, res)
    ok, res = exec("rename", "rt:type1", "rt:rn1")
    self:report("rename", ok, res, res)
    ok, res = exec("exists", "rt:rn1")
    self:report("verify renamed key exists", ok and res == true, res, res)
end

return RedisTest
