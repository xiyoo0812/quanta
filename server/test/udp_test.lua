-- udp_test.lua

local log_debug     = logger.debug

local thread_mgr    = quanta.get("thread_mgr")

if quanta.index == 1 then
    local udp = luabus.udp()
    local ok, err = udp.bind("127.0.0.1", 8600, true)
    log_debug("udp-svr bind: {}, err: {}", ok, err)
    thread_mgr:fork(function()
        local index = 0
        while true do
            local ok2, buf, ip, port = udp.recv()
            if ok2 then
                index = index + 1
                log_debug("udp-svr recv: {} from {}:{}", buf, ip, port)
                local buff = string.format("server send %d", index)
                udp.send(buff, #buff, ip, port)
            else
                if buf ~= "EWOULDBLOCK" then
                    log_debug("udp-svr recv failed: {}-{}", buf, ip)
                end
            end
            thread_mgr:sleep(1000)
        end
    end)
elseif quanta.index == 2 then
    local udp = luabus.udp()
    local ok, err = udp.bind("127.0.0.1", 8601, true)
    log_debug("udp-cli bind: {}, err: {}", ok, err)
    thread_mgr:fork(function()
        local index = 0
        local cdata = "client send 0!"
        udp.send(cdata, #cdata, "127.0.0.1", 8600)
        while true do
            local ok2, buf, ip, port = udp.recv()
            if ok2 then
                index = index + 1
                log_debug("udp-cli recv: {} from {}:{}", buf, ip, port)
                local buff = string.format("client send %d", index)
                udp.send(buff, #buff, ip, port)
            else
                if buf ~= "EWOULDBLOCK" then
                    log_debug("udp-cli recv failed: {}", buf)
                end
            end
            thread_mgr:sleep(1000)
        end
    end)
end
