-- etcd_test.lua
local sformat       = string.format
local log_info      = logger.info
local qetcd         = quanta.etcd

local thread_mgr    = quanta.get("thread_mgr")

local TestCase      = import("test/case.lua")
local EtcdTest      = class(TestCase)

--准备: 建客户端并等待连接就绪(异常时由基类 teardown 兜底清理)
function EtcdTest:setup()
    self.etcd = qetcd(self.addr or "http://127.0.0.1:2379")
    thread_mgr:sleep(2000)
end

--清理: 无论测试成功/异常都执行, 保证 /test/ 数据不残留
function EtcdTest:on_cleanup()
    if not self.etcd then
        return
    end
    local ok, res = self.etcd:delete({ key = "/test/", range_end = "/test0" })
    self:report("cleanup /test/", ok, res, res)
end

function EtcdTest:run()
    local etcd = self.etcd

    ------------------------------------------------------------------
    --1. KV 基础: put/get
    ------------------------------------------------------------------
    local ok, res = etcd:put({ key = "/test/k1", value = "v1" })
    self:report("put /test/k1", ok, res, res)
    thread_mgr:sleep(100)

    ok, res = etcd:get({ key = "/test/k1" })
    local kvs = ok and res.kvs or nil
    self:report("get /test/k1", ok and kvs and kvs[1] and kvs[1].value == "v1", ok and res, res)

    ------------------------------------------------------------------
    --2. 范围查询（前缀）: /test/a1 /test/a2, 用 range_end 拉全前缀
    ------------------------------------------------------------------
    ok, res = etcd:put({ key = "/test/a1", value = "p1" })
    self:report("put /test/a1", ok, res, res)
    ok, res = etcd:put({ key = "/test/a2", value = "p2" })
    self:report("put /test/a2", ok, res, res)
    thread_mgr:sleep(100)

    ok, res = etcd:get({ key = "/test/", range_end = "/test0" })
    local count = ok and res.kvs and #res.kvs or 0
    self:report("get prefix /test/ (expect >= 3)", ok and count >= 3, sformat("count=%d", count), res)

    ------------------------------------------------------------------
    --3. delete + get 验证已删
    ------------------------------------------------------------------
    ok, res = etcd:delete({ key = "/test/a2" })
    self:report("delete /test/a2", ok, res, res)
    thread_mgr:sleep(100)
    ok, res = etcd:get({ key = "/test/a2" })
    self:report("get deleted /test/a2 (expect empty)", ok and (not res.kvs or #res.kvs == 0), ok and res, res)

    ------------------------------------------------------------------
    --4. watch 单键: put 触发事件, unwatch 后不再触发
    ------------------------------------------------------------------
    local w1_hit = false
    ok, res = etcd:watch("/test/w1", function(events)
        w1_hit = true
        local ev = events and events[1]
        log_info("[EtcdTest] watch /test/w1 event: type={}, key={}, value={}", ev.type, ev.kv.key, ev.kv.value)
    end)
    self:report("watch /test/w1", ok, res, res)
    thread_mgr:sleep(500)   --等 created 确认

    ok, res = etcd:put({ key = "/test/w1", value = "wv1" })
    self:report("put /test/w1 (trigger watch)", ok, res, res)
    thread_mgr:sleep(500)
    self:report("watch /test/w1 callback fired", w1_hit, w1_hit, "callback not fired")

    ok = etcd:unwatch("/test/w1")
    self:report("unwatch /test/w1", ok, ok, ok)
    thread_mgr:sleep(300)   --等RST_STREAM送达服务端并清掉watcher
    w1_hit = false
    etcd:put({ key = "/test/w1", value = "wv2" })
    thread_mgr:sleep(500)
    self:report("watch /test/w1 not fired after unwatch", not w1_hit, w1_hit, "callback should not fire")

    ------------------------------------------------------------------
    --5. watch 前缀: /test/p/ 下任意键都触发, 其他前缀不触发
    ------------------------------------------------------------------
    local p_hit = 0
    ok, res = etcd:watch("/test/p/", function(events)
        p_hit = p_hit + 1
        local ev = events and events[1]
        log_info("[EtcdTest] watch /test/p/ event: type={}, key={}", ev.type, ev.kv.key)
    end, "/test/p0")
    self:report("watch prefix /test/p/", ok, res, res)
    thread_mgr:sleep(500)

    etcd:put({ key = "/test/p/x", value = "1" })
    etcd:put({ key = "/test/p/y", value = "2" })
    etcd:put({ key = "/test/q/z", value = "3" })    --不在监听范围
    thread_mgr:sleep(500)
    self:report("prefix watch fired 2 times (x,y)", p_hit == 2, sformat("hits=%d", p_hit), sformat("hits=%d", p_hit))
    self:report("out-of-range put ignored", p_hit == 2, sformat("hits=%d", p_hit), "unexpected event")

    ------------------------------------------------------------------
    --6. watch 删除事件
    ------------------------------------------------------------------
    p_hit = 0
    ok, res = etcd:delete({ key = "/test/p/x" })
    self:report("delete /test/p/x (trigger watch)", ok, res, res)
    thread_mgr:sleep(500)
    self:report("prefix watch delete event", p_hit >= 1, p_hit, "no event")

    ------------------------------------------------------------------
    --7. Lease 全流程: grant -> 绑定 key -> ttl -> keepalive -> revoke -> key 消失
    ------------------------------------------------------------------
    ok, res = etcd:lease({ ttl = 10 })
    --proto 字段名是 ID, 兼容大小写两种解码形式
    local lease_id = ok and (res.ID or res.id) or nil
    self:report("lease grant (ttl=10)", ok and lease_id, ok and res, res)

    ok, res = etcd:put({ key = "/test/lease", value = "tmp", lease = lease_id })
    self:report("put /test/lease with lease", ok, res, res)

    ok, res = etcd:ttl({ ID = lease_id, keys = true })
    local ttl_left = ok and (res.TTL or res.ttl) or nil
    self:report("lease ttl (expect > 0)", ok and ttl_left and ttl_left > 0, ok and res, res)

    ok, res = etcd:keepalive({ ID = lease_id })
    self:report("lease keepalive", ok, res, res)

    ok, res = etcd:revoke({ ID = lease_id })
    self:report("lease revoke", ok, res, res)
    thread_mgr:sleep(200)
    ok, res = etcd:get({ key = "/test/lease" })
    self:report("get /test/lease after revoke (expect empty)", ok and (not res.kvs or #res.kvs == 0), ok and res, res)

    ------------------------------------------------------------------
    --8. 人工验证入口(不计入断言结果; 数据清理由 teardown 统一完成)
    ------------------------------------------------------------------
    log_info("[EtcdTest] 自动化测试结束。人工验证 watch 重连恢复:")
    log_info("[EtcdTest]   1. 保持本进程运行, 重启 etcd 服务 (断开 TCP)")
    log_info("[EtcdTest]   2. 观察日志: [Etcd][on_socket_error] -> [Etcd][login] -> [Etcd][recover_watches]")
    log_info("[EtcdTest]   3. 重启后执行: etcdctl put /test/p/recover hello")
    log_info("[EtcdTest]   4. 应看到 [EtcdTest] watch /test/p/ event 打印, 且 revision 续传无丢事件")
end

return EtcdTest
