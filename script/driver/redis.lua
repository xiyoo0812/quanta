--redis.lua
local json          = require("ljson")
local Socket        = import("driver/socket.lua")

local tonumber      = tonumber
local crc16         = tls.crc16
local log_err       = logger.err
local log_info      = logger.info
local log_debug     = logger.debug
local tinsert       = table.insert
local terase        = table.erase
local tpack         = table.pack
local tunpack       = table.unpack
local mrandom       = qmath.random
local lnext_id      = luakit.next_id
local qhash         = codec.hash_code
local jsoncodec     = json.jsoncodec
local rediscodec    = codec.rediscodec
local make_timer    = quanta.make_timer
local make_functer  = quanta.make_functer
local makechan      = quanta.make_channel

local thread_mgr    = quanta.get("thread_mgr")
local event_mgr     = quanta.get("event_mgr")
local update_mgr    = quanta.get("update_mgr")

local SUCCESS       = quanta.enum("KernCode", "SUCCESS")
local FAST_MS       = quanta.enum("PeriodTime", "FAST_MS")
local SECOND_MS     = quanta.enum("PeriodTime", "SECOND_MS")
local SECOND_10_MS  = quanta.enum("PeriodTime", "SECOND_10_MS")
local DBCALL_TO     = quanta.enum("NetwkTime", "DB_CALL_TIMEOUT")
local CONNECT_TO    = quanta.enum("NetwkTime", "CONNECT_TIMEOUT")

local POOL_COUNT    = environ.number("QUANTA_DB_POOL_COUNT", 3)
local REDIS_SLOT    = 16384

local function _tomap(value)
    if (type(value) == 'table') then
        -- resp3 map直接解码为kv表, 无需再按奇偶位折叠
        if value[1] == nil and next(value) ~= nil then
            return value
        end
        local maps = { }
        for i = 1, #value, 2 do
            maps[value[i]] = value[i + 1]
        end
        return maps
    end
    return {}
end

local function _toboolean(value)
    -- resp3 boolean直接解码为lua boolean; resp2数字/字符串走兼容分支
    if type(value) == 'boolean' then
        return value
    end
    local number = tonumber(value)
    if number then
        return number ~= 0
    end
    return value == 'true' or value == 'TRUE'
end

local function _toscan(value)
    if (type(value) == 'table') then
        return tonumber(value[1]), value[2]
    end
    return 0, {}
end

local function _tohscan(value)
    if (type(value) == 'table') then
        return tonumber(value[1]), _tomap(value[2])
    end
    return 0, {}
end

-- RESP3 实测(Redis 8.6.2)后清理:
--   codec 已原生产出 map(kv表)/double(number)/boolean, 三类 convertor 直接删除:
--     zincrby(double), hgetall/config(map), 及原 setnx/exists/... 中的 bool 语义(但仍需 integer->bool, 保留)
--   注意 bool 类命令 RESP3 仍返回 integer(1/0), 不是 boolean, 故 _toboolean 保留
--   注意 incrbyfloat/hincrbyfloat 即使 RESP3 仍返回 blob 字符串, 故 tonumber 保留
--   scan/hscan 返回 array[2]{cursor字符串, flat数组}, 需 _toscan/_tohscan 拆包+折叠, 保留
local rconvertors = {
    scan            =   _toscan,
    sscan           =   _toscan,
    hscan           =   _tohscan,
    zscan           =   _tohscan,
    incrbyfloat     =   tonumber,
    hincrbyfloat    =   tonumber,
    setnx           =   _toboolean,
    exists          =   _toboolean,
    renamenx        =   _toboolean,
    expire          =   _toboolean,
    pexpire         =   _toboolean,
    expireat        =   _toboolean,
    pexpireat       =   _toboolean,
    move            =   _toboolean,
    persist         =   _toboolean,
    smove           =   _toboolean,
    sismember       =   _toboolean,
    hset            =   _toboolean,
    hsetnx          =   _toboolean,
    hexists         =   _toboolean,
    msetnx          =   _toboolean,
}

-- RESP3 push 派发: message/pmessage 走业务回调, subscribe/unsubscribe 维护订阅状态
local function dispatch_push(self, res)
    if type(res) ~= "table" then
        return
    end
    local kind, channel, data, data2 = tunpack(res)
    if kind == "message" then
        local callback = self.callbacks[channel]
        if callback then
            callback(channel, data)
        end
    elseif kind == "pmessage" then
        local callback = self.callbacks[channel]
        if callback then
            callback(data, data2)   -- pattern=channel(订阅key), data=实际channel, data2=payload
        end
    elseif kind == "subscribe" then
        self.subscribes[channel] = true
    elseif kind == "psubscribe" then
        self.psubscribes[channel] = true
    elseif kind == "unsubscribe" then
        self.subscribes[channel] = nil
        self.callbacks[channel] = nil
    elseif kind == "punsubscribe" then
        self.psubscribes[channel] = nil
        self.callbacks[channel] = nil
    end
end

local RedisDB = class()
local prop = property(RedisDB)
prop:reader("timer", nil)           --timer
prop:reader("passwd", nil)          --passwd
prop:reader("jcodec", nil)          --jcodec
prop:reader("rcfunctor", nil)       --rcfunctor
prop:reader("connections", {})      --connections
prop:reader("clusters", {})         --clusters
prop:reader("alives", {})           --alives
prop:reader("slots", {})            --slots
prop:reader("cluster", false)       --cluster
prop:reader("resp3", false)         --是否已升级到resp3
prop:reader("refreshing", false)    --拓扑刷新中(防并发重入)
-- 订阅状态(RESP3 下任意连接可订阅, 无需独立订阅连接)
prop:reader("callbacks", {})        --channel/pattern -> callback
prop:reader("subscribes", {})       --channel -> true
prop:reader("psubscribes", {})      --pattern -> true
prop:reader("sub_socks", {})        --channel/pattern -> socket(订阅所在连接, 断线重连用)

function RedisDB:__init(conf)
    self.passwd = conf.passwd
    self:set_options(conf.opts)
    --attach_hour
    update_mgr:attach_hour(self)
    --codec
    self.jcodec = jsoncodec()
    self.timer = make_timer()
    --setup
    self:setup(conf)
end

function RedisDB:close()
    for _, sock in pairs(self.alives) do
        sock:close()
    end
    for _, sock in pairs(self.connections) do
        sock:close()
    end
    self.timer:unregister()
    self.connections = {}
    self.alives = {}
end

function RedisDB:setup(conf)
    self:setup_pool(conf.hosts)
    self.rcfunctor = make_functer("check_alive", CONNECT_TO)
    self.timer:register(FAST_MS, SECOND_MS, -1, function()
        self.rcfunctor:run(self)
    end)
end

function RedisDB:on_minute()
    self:check_clusters()
end

function RedisDB:setup_pool(hosts)
    if not next(hosts) then
        log_err("[RedisDB][setup_pool] redis config err: hosts is empty")
        return
    end
    local count = 1
    for _, host in pairs(hosts) do
        for _ = 1, POOL_COUNT do
            local socket = Socket(self, host[1], host[2])
            self.connections[count] = socket
            socket:set_id(count)
            count = count + 1
        end
    end
end

function RedisDB:choose_node(key)
    if self.cluster and type(key) == "string" then
        local index = crc16(key) % REDIS_SLOT
        for _, cluster in pairs(self.clusters) do
            if index >= cluster.min and index <= cluster.max then
                local count = #cluster.alives
                if count > 0 then
                    return cluster.alives[(index % count) + 1]
                end
            end
        end
        return
    end
    local count = #self.alives
    if count > 0 then
        local index = qhash(key or mrandom(), count)
        return self.alives[index]
    end
end

function RedisDB:set_options(opts)
    if opts.cluster then
        log_debug("[RedisDB][set_options] cluster status open")
        self.cluster = true
        update_mgr:attach_minute(self)
    end
end

function RedisDB:available()
    return #self.alives > 0
end

function RedisDB:on_hour()
    for _, sock in pairs(self.alives) do
        self:direct_send(sock, "PING")
    end
end

function RedisDB:check_clusters()
    if not self.cluster or self.refreshing then
        return
    end
    local _, socket = next(self.alives)
    if not socket then
        return
    end
    self.refreshing = true
    local ok, res = self:commit(socket, "cluster", "slots")
    self.refreshing = false
    if not ok then
        log_err("[RedisDB][check_clusters] load cluster slots failed! because: {}", res)
        return
    end
    self.slots = {}
    self.clusters = {}
    for i, info in pairs(res) do
        for j = 3, #info do
            self.slots[info[j][2]] = i
        end
        self.clusters[i] = { min = info[1], max = info[2], alives = {} }
    end
    for _, sock in pairs(self.alives) do
        local index = self.slots[sock.port] or 0
        local cluster = self.clusters[index]
        if cluster then
            tinsert(cluster.alives, sock)
        end
    end
end

function RedisDB:check_alive()
    if next(self.connections) then
        local channel = makechan("check redis")
        for _, sock in pairs(self.connections) do
            channel:push(function()
                return self:login(sock)
            end)
        end
        if channel:execute(true) then
            self.timer:change_period(SECOND_10_MS)
            self:check_clusters()
        end
    end
end

function RedisDB:login(socket)
    local id, ip, port = socket.id, socket.ip, socket.port
    local ok, err = socket:connect(ip, port)
    if not ok then
        log_err("[RedisDB][login] connect db({}:{}:{}:{}) failed: {}!", ip, port, self.name, id, err)
        return false
    end
    socket:set_codec(rediscodec(self.jcodec))
    if self.passwd and #self.passwd > 0 then
        local aok, res = self:auth(socket)
        if not aok or res ~= "OK" then
            log_err("[RedisDB][login] auth db({}:{}:{}) auth failed! because: {}", ip, port, id, res)
            self:delive(socket)
            socket:close()
            return false
        end
    end
    --hello3: 强制升级到resp3(map/bool/double原生类型 + push通道); 失败则连接不可用
    --  (rconvertors 已按 RESP3 精简, RESP2 下结构不匹配, 不再兼容)
    local hok, hres = self:commit(socket, "HELLO", 3)
    if not hok or type(hres) ~= "table" or hres.proto ~= 3 then
        log_err("[RedisDB][login] hello3 db({}:{}:{}) failed: {}", ip, port, id, hres)
        self:delive(socket)
        socket:close()
        return false
    end
    self.resp3 = true
    self.connections[id] = nil
    tinsert(self.alives, socket)
    log_info("[RedisDB][login] login db({}:{}:{}) success!", ip, port, id)
    event_mgr:fire_frame(function()
        self:on_socket_alive(socket)
    end)
    return true, SUCCESS
end

function RedisDB:auth(sock)
    return self:commit(sock, "AUTH", self.passwd)
end

function RedisDB:on_socket_alive(socket)
    --连接建立/重连后, 重新绑定并发出尚未挂到有效连接的订阅
    --  (订阅意图 callbacks/subscribes 保留到显式退订; sub_socks 断线时清空)
    for channel in pairs(self.subscribes) do
        local csock = self.sub_socks[channel]
        if not csock or not csock:is_ready() then
            local sock = self:choose_node(channel)
            if sock then
                self.sub_socks[channel] = sock
                self:direct_send(sock, "SUBSCRIBE", channel)
            end
        end
    end
    for pattern in pairs(self.psubscribes) do
        local csock = self.sub_socks[pattern]
        if not csock or not csock:is_ready() then
            local sock = self:choose_node(pattern)
            if sock then
                self.sub_socks[pattern] = sock
                self:direct_send(sock, "PSUBSCRIBE", pattern)
            end
        end
    end
end

function RedisDB:delive(sock)
    if self.cluster then
        local index = self.slots[sock.port] or 0
        local cluster = self.clusters[index]
        if cluster then
            terase(cluster.alives, sock)
        end
    end
    terase(self.alives, sock)
    self.connections[sock.id] = sock
end

function RedisDB:on_socket_error(sock, token, err)
    --连接断开: 仅清连接绑定(保留订阅意图), 重连后由 on_socket_alive 重新选连接发出
    for channel, csock in pairs(self.sub_socks) do
        if csock == sock then
            self.sub_socks[channel] = nil
        end
    end
    self:delive(sock)
    self.timer:change_period(SECOND_MS)
end

function RedisDB:on_socket_recv(sock, session_id, succ, res, is_push)
    if is_push then
        --RESP3 push: 带外数据, 不占session队列也不应答等待协程; 统一走订阅派发
        dispatch_push(self, res)
        self:on_push(res)
        return
    end
    if session_id > 0 then
        thread_mgr:response(session_id, succ, res)
    end
end

function RedisDB:on_push(res)
    --push 扩展点(如客户端缓存失效), 子类可重写; 订阅消息已由 dispatch_push 处理
end

--按 channel 的 hash 选择连接发送订阅(RESP3 下任意连接均可订阅)
--订阅意图先落地, 若当前无连接则由 on_socket_alive 补发
function RedisDB:subscribe(callback, channel)
    if self.callbacks[channel] then
        return true
    end
    self.callbacks[channel] = callback
    self.subscribes[channel] = true
    local sock = self:choose_node(channel)
    if not sock then
        return true, "pending"
    end
    self.sub_socks[channel] = sock
    return self:direct_send(sock, "SUBSCRIBE", channel)
end

function RedisDB:psubscribe(callback, pattern)
    if self.callbacks[pattern] then
        return true
    end
    self.callbacks[pattern] = callback
    self.psubscribes[pattern] = true
    local sock = self:choose_node(pattern)
    if not sock then
        return true, "pending"
    end
    self.sub_socks[pattern] = sock
    return self:direct_send(sock, "PSUBSCRIBE", pattern)
end

function RedisDB:unsubscribe(channel)
    local sock = self.sub_socks[channel]
    if not sock then
        return false, "watcher not found"
    end
    self.sub_socks[channel] = nil
    self.callbacks[channel] = nil
    self.subscribes[channel] = nil
    return self:direct_send(sock, "UNSUBSCRIBE", channel)
end

function RedisDB:punsubscribe(pattern)
    local sock = self.sub_socks[pattern]
    if not sock then
        return false, "watcher not found"
    end
    self.sub_socks[pattern] = nil
    self.callbacks[pattern] = nil
    self.psubscribes[pattern] = nil
    return self:direct_send(sock, "PUNSUBSCRIBE", pattern)
end

function RedisDB:commit(socket, cmd, ...)
    local session_id = lnext_id()
    if not socket:send_data(session_id, cmd, ...) then
        return false, "send request failed"
    end
    local ok, res = thread_mgr:yield(session_id, cmd, DBCALL_TO)
    if not ok then
        log_err("[RedisDB][commit] exec cmd {} failed: {}", cmd, res)
        return ok, res
    end
    local convertor = rconvertors[cmd:lower()]
    if convertor then
        return ok, convertor(res)
    end
    return ok, res
end

function RedisDB:send(cmd, key, ...)
    local sock = self:choose_node(key)
    if sock then
        sock:send_data(0, cmd, key, ...)
    end
end

function RedisDB:direct_send(sock, cmd, ...)
    return sock:send_data(0, cmd, ...)
end

function RedisDB:handle_redirect(cmd, key, res, ...)
    if not self.cluster or type(res) ~= "string" then
        return false
    end
    if res:match("^MOVED ") then
        self:check_clusters()
        local sock = self:choose_node(key)
        if sock then
            --MOVED 重试同样要保留 convertor 的多返回值
            local redirected = tpack(self:commit(sock, cmd, key, ...))
            return true, tunpack(redirected, 1, redirected.n)
        end
    end
    return false
end

function RedisDB:execute(cmd, key, ...)
    local sock = self:choose_node(key)
    if not sock then
        return false, "db not connected"
    end
    --commit 的 convertor 可能返回多值(scan/hscan: cursor, data), 必须整体透传,
    --否则上层拿到的第二个值之后全部丢失
    local res = tpack(self:commit(sock, cmd, key, ...))
    if not res[1] then
        local redirect = tpack(self:handle_redirect(cmd, key, res[2], ...))
        if redirect[1] then
            return tunpack(redirect, 2, redirect.n)
        end
    end
    return tunpack(res, 1, res.n)
end

return RedisDB
