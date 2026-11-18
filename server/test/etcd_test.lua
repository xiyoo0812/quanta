-- etcd_test.lua
-- 测试前置: 本地启动 etcd (gRPC 端口 2379), 日志级别调到 debug 可看协议细节
-- 覆盖: KV put/get/范围查询/delete, lease grant/ttl/keepalive/revoke 全流程,
--       watch(单键+前缀)事件, unwatch, 断线重连 watch 自动恢复（人工拔线验证）

local log_err       = logger.err
local log_info      = logger.info
local log_dump      = logger.dump
local sformat       = string.format
local qetcd         = quanta.etcd

local thread_mgr    = quanta.get("thread_mgr")

local PASS, FAIL = 0, 0

local function report(title, ok, res, err)
    if ok then
        PASS = PASS + 1
        log_dump("[TEST][OK] {}: {}", title, res)
    else
        FAIL = FAIL + 1
        log_err("[TEST][FAIL] {}: {}, {}", title, res, err)
    end
end

thread_mgr:fork(function()
    local etcd = qetcd("http://127.0.0.1:2379")
    thread_mgr:sleep(2000)

    ------------------------------------------------------------------
    --1. KV 基础: put/get
    ------------------------------------------------------------------
    local ok, res = etcd:put({ key = "/test/k1", value = "v1" })
    report("put /test/k1", ok, res, res)
    thread_mgr:sleep(100)

    ok, res = etcd:get({ key = "/test/k1" })
    local kvs = ok and res.kvs or nil
    report("get /test/k1", ok and kvs and kvs[1] and kvs[1].value == "v1", ok and res, res)

    ------------------------------------------------------------------
    --2. 范围查询（前缀）: /test/a1 /test/a2, 用 range_end 拉全前缀
    ------------------------------------------------------------------
    ok, res = etcd:put({ key = "/test/a1", value = "p1" })
    report("put /test/a1", ok, res, res)
    ok, res = etcd:put({ key = "/test/a2", value = "p2" })
    report("put /test/a2", ok, res, res)
    thread_mgr:sleep(100)

    ok, res = etcd:get({ key = "/test/", range_end = "/test0" })
    local count = ok and res.kvs and #res.kvs or 0
    report("get prefix /test/ (expect >= 3)", ok and count >= 3, sformat("count=%d", count), res)

    ------------------------------------------------------------------
    --3. delete + get 验证已删
    ------------------------------------------------------------------
    ok, res = etcd:delete({ key = "/test/a2" })
    report("delete /test/a2", ok, res, res)
    thread_mgr:sleep(100)
    ok, res = etcd:get({ key = "/test/a2" })
    report("get deleted /test/a2 (expect empty)", ok and (not res.kvs or #res.kvs == 0), ok and res, res)

    ------------------------------------------------------------------
    --4. watch 单键: put 触发事件, unwatch 后不再触发
    ------------------------------------------------------------------
    local w1_hit = false
    ok, res = etcd:watch("/test/w1", function(events)
        w1_hit = true
        local ev = events and events[1]
        log_info("[TEST][WATCH] /test/w1 event: type={}, key={}, value={}",
            ev and ev.type, ev and ev.kv and ev.kv.key, ev and ev.kv and ev.kv.value)
    end)
    report("watch /test/w1", ok, res, res)
    thread_mgr:sleep(500)   --等 created 确认

    ok, res = etcd:put({ key = "/test/w1", value = "wv1" })
    report("put /test/w1 (trigger watch)", ok, res, res)
    thread_mgr:sleep(500)
    report("watch /test/w1 callback fired", w1_hit, w1_hit, "callback not fired")

    ok = etcd:unwatch("/test/w1")
    report("unwatch /test/w1", ok, ok, ok)
    thread_mgr:sleep(300)   --等RST_STREAM送达服务端并清掉watcher
    w1_hit = false
    etcd:put({ key = "/test/w1", value = "wv2" })
    thread_mgr:sleep(500)
    report("watch /test/w1 not fired after unwatch", not w1_hit, w1_hit, "callback should not fire")

    ------------------------------------------------------------------
    --5. watch 前缀: /test/p/ 下任意键都触发, 其他前缀不触发
    ------------------------------------------------------------------
    local p_hit = 0
    ok, res = etcd:watch("/test/p/", function(events)
        p_hit = p_hit + 1
        local ev = events and events[1]
        log_info("[TEST][WATCH] /test/p/ event: type={}, key={}",
            ev and ev.type, ev and ev.kv and ev.kv.key)
    end, "/test/p0")
    report("watch prefix /test/p/", ok, res, res)
    thread_mgr:sleep(500)

    etcd:put({ key = "/test/p/x", value = "1" })
    etcd:put({ key = "/test/p/y", value = "2" })
    etcd:put({ key = "/test/q/z", value = "3" })    --不在监听范围
    thread_mgr:sleep(500)
    report("prefix watch fired 2 times (x,y)", p_hit == 2, sformat("hits=%d", p_hit), sformat("hits=%d", p_hit))
    report("out-of-range put ignored", p_hit == 2, sformat("hits=%d", p_hit), "unexpected event")

    ------------------------------------------------------------------
    --6. watch 删除事件
    ------------------------------------------------------------------
    p_hit = 0
    ok, res = etcd:delete({ key = "/test/p/x" })
    report("delete /test/p/x (trigger watch)", ok, res, res)
    thread_mgr:sleep(500)
    report("prefix watch delete event", p_hit >= 1, p_hit, "no event")

    ------------------------------------------------------------------
    --7. Lease 全流程: grant -> 绑定 key -> ttl -> keepalive -> revoke -> key 消失
    ------------------------------------------------------------------
    ok, res = etcd:lease({ ttl = 10 })
    --proto 字段名是 ID, 兼容大小写两种解码形式
    local lease_id = ok and (res.ID or res.id) or nil
    report("lease grant (ttl=10)", ok and lease_id, ok and res, res)

    ok, res = etcd:put({ key = "/test/lease", value = "tmp", lease = lease_id })
    report("put /test/lease with lease", ok, res, res)

    ok, res = etcd:ttl({ ID = lease_id, keys = true })
    local ttl_left = ok and (res.TTL or res.ttl) or nil
    report("lease ttl (expect > 0)", ok and ttl_left and ttl_left > 0, ok and res, res)

    ok, res = etcd:keepalive({ ID = lease_id })
    report("lease keepalive", ok, res, res)

    ok, res = etcd:revoke({ ID = lease_id })
    report("lease revoke", ok, res, res)
    thread_mgr:sleep(200)
    ok, res = etcd:get({ key = "/test/lease" })
    report("get /test/lease after revoke (expect empty)", ok and (not res.kvs or #res.kvs == 0), ok and res, res)

    ------------------------------------------------------------------
    --8. 清理测试数据
    ------------------------------------------------------------------
    ok, res = etcd:delete({ key = "/test/", range_end = "/test0" })
    report("cleanup /test/", ok, res, res)

    ------------------------------------------------------------------
    --9. 汇总 + 人工验证入口
    ------------------------------------------------------------------
    log_info("[TEST] ================== RESULT: pass={}, fail={} ==================", PASS, FAIL)
    log_info("[TEST] 自动化测试结束。人工验证 watch 重连恢复:")
    log_info("[TEST]   1. 保持本进程运行, 重启 etcd 服务 (断开 TCP)")
    log_info("[TEST]   2. 观察日志: [Etcd][on_socket_error] -> [Etcd][login] -> [Etcd][recover_watches]")
    log_info("[TEST]   3. 重启后执行: etcdctl put /test/p/recover hello")
    log_info("[TEST]   4. 应看到 [TEST][WATCH] /test/p/ event 打印, 且 revision 续传无丢事件")

    while true do
        thread_mgr:sleep(1000)
    end
end)
