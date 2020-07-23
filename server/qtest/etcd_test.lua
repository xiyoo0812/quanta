-- etcd_test.lua
local Etcd = import("driver/etcd.lua")

local thread_mgr = quanta.thread_mgr

local EtcdTest = singleton()
function EtcdTest:__init()
    self:setup()
end

function EtcdTest:setup()
    --测试代码
    local etcd = Etcd("http://10.100.0.19:2379")
    thread_mgr:fork(function()
        if quanta.index == 1 then
            local ok, res = etcd:version()
            print(ok, res)
            ok, res = etcd:set("/quanta", {Network = "10.10.0.0/16", Backend = {Type = "vxlan"}})
            print(ok, res)
            ok, res = etcd:get("/quanta")
            print(ok, res)
        else
            for index = 1, 100 do
                local ok, res = etcd:wait("/quanta")
                print(ok, res)
            end
        end
    end)
end

-- export
quanta.etcd_test = EtcdTest()

return EtcdTest
