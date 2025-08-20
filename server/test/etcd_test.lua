-- http2_test.lua

local log_debug     = logger.debug
local qetcd         = quanta.etcd

local thread_mgr    = quanta.get("thread_mgr")


thread_mgr:fork(function()
    local etcd = qetcd("http://127.0.0.1:2379")
    thread_mgr:sleep(2000)
    local ok, res = etcd:get({ key="/ccc" })
    log_debug("etcd get : {}, {}", ok, res)
    ok, res = etcd:put({ key="/ccc", value="123" })
    log_debug("etcd put : {}, {}", ok, res)
    ok, res = etcd:delete({ key="/aaa" })
    log_debug("etcd del : {}, {}", ok, res)
    ok, res = etcd:watch({ create_request={key = "/ccc", watch_id = 9999 } })
    log_debug("etcd watch : {}, {}", ok, res)

    while true do
        thread_mgr:sleep(100)
    end
end)
