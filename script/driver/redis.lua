--redis.lua
local Socket        = import("driver/socket.lua")
local QueueFIFO     = import("container/queue_fifo.lua")

local ipairs        = ipairs
local tonumber      = tonumber
local log_err       = logger.err
local log_info      = logger.info
local ssub          = string.sub
local sbyte         = string.byte
local sformat       = string.format
local sgmatch       = string.gmatch
local tinsert       = table.insert
local tunpack       = table.unpack

local NetwkTime     = enum("NetwkTime")
local KernCode      = enum("KernCode")
local SUCCESS       = KernCode.SUCCESS
local REDIS_FAILED  = KernCode.REDIS_FAILED
local DB_TIMEOUT    = NetwkTime.DB_CALL_TIMEOUT

local LineFlag      = "\r\n"

local update_mgr    = quanta.get("update_mgr")
local thread_mgr    = quanta.get("thread_mgr")

local function _async_call(self, quote)
    self.sessions:push(thread_mgr:build_session_id())
    return thread_mgr:yield(session_id, quote, DB_TIMEOUT)
end

local _redis_resp_parser = {
    ["+"] = function(self, body)
        --simple string
        return true, body
    end,
    ["-"] = function(self, body)
        -- error reply
        return false, body
    end,
    [":"] = function(self, body)
        -- integer reply
        return false, tonumber(body)
    end,
    ["$"] = function(self, body)
        -- bulk string
        if tonumber(body) < 0 then
            return true, nil
        end
        return _async_call(self, "redis parse bulk string")
    end,
    ["*"] = function(self, body)
        local length = tonumber(body)
        if length < 0 then
            return true, nil
        end
        local array = {}
        local noerr = true
        for i = 1, length do
            local ok, value _async_call(self, "redis parse array")
            if not ok then
                noerr = false
            end
            array[i] = value
        end
        return noerr, array
    end
}

local RedisDB = class()
local prop = property(RedisDB)
prop:reader("ip", nil)          --redis地址
prop:reader("sock", nil)        --网络连接对象
prop:reader("index", "")        --db index
prop:reader("port", 6379)       --redis端口
prop:reader("passwd", "")       --passwd
prop:reader("sessions", nil)    --sessions

function RedisDB:__init(conf)
    self.ip = conf.host
    self.port = conf.port
    self.passwd = conf.passwd
    self.index = conf.db
    self.sessions = QueueFIFO()
    --attach_second
    update_mgr:attach_second(self)
end

function RedisDB:__release()
    self:close()
end

function RedisDB:close()
    if self.sock then
        self.sessions:clear()
        self.sock:close()
        self.sock = nil
    end
end

function RedisDB:on_second()
    if not self.sock then
        local sock = Socket(self)
        if sock:connect(self.ip, self.port) then
            self.sock = sock
            if #self.passwd > 0 then
                local ok, err = self:auth(self.passwd)
                if not ok then
                    log_err("[RedisDB][on_second] auth db(%s:%s) failed! because: %s", self.ip, self.port, err)
                    self.sock = nil
                    return
                end
                log_info("[RedisDB][on_second] auth db(%s:%s) success!", self.ip, self.port)
            end
            log_info("[RedisDB][on_second] connect db(%s:%s) success!", self.ip, self.port)
        else
            log_err("[MysqlDB][on_second] connect db(%s:%s) failed!", self.ip, self.port)
        end
    end
end

function RedisDB:on_socket_close()
    self.sessions:clear()
    self.sock = nil
end

function RedisDB:on_socket_recv(sock)
    while true do
        local line, length = sock:peek_line(LineFlag)
        if not line then
            break
        end
        sock:pop(length)
        local session_id = self.sessions:pop()
        if session_id then
            thread_mgr:fork(function()
                local prefix, body = sbyte(line), ssub(line, 2)
                local prefix_func = _redis_resp_parser[prefix]
                if prefix_func then
                    thread_mgr:response(session_id, prefix_func(self, body))
                end
                thread_mgr:response(session_id, true, line)
            end)
        end
    end
end

function RedisDB:auth(password)
    return self:command("AUTH", password)
end

local function _toboolean(value) return value == 1 end
local function _parse_boolean(v)
    if v == '1' or v == 'true' or v == 'TRUE' then
        return true
    elseif v == '0' or v == 'false' or v == 'FALSE' then
        return false
    end
    return nil
end

--params = { by = 'weight_*', get = 'object_*', limit = { 0, 10 }, sort = 'desc', alpha = true }
local function sort_request(client, command, key, params)
    local query = { key }
    if params then
        if params.by then
            tinsert(query, 'BY')
            tinsert(query, params.by)
        end
        if type(params.limit) == 'table' then
            -- TODO: check for lower and upper limits
            tinsert(query, 'LIMIT')
            tinsert(query, params.limit[1])
            tinsert(query, params.limit[2])
        end
        if params.get then
            if type(params.get) == 'table' then
                for _, getarg in pairs(params.get) do
                    tinsert(query, 'GET')
                    tinsert(query, getarg)
                end
            else
                tinsert(query, 'GET')
                tinsert(query, params.get)
            end
        end
        if params.sort then
            tinsert(query, params.sort)
        end
        if params.alpha == true then
            tinsert(query, 'ALPHA')
        end
        if params.store then
            tinsert(query, 'STORE')
            tinsert(query, params.store)
        end
    end
    request.multibulk(client, command, query)
end

local function zset_range_request(client, command, ...)
    local args, opts = {...}, { }
    if #args >= 1 and type(args[#args]) == 'table' then
        local options = table.remove(args, #args)
        if options.withscores then
            tinsert(opts, 'WITHSCORES')
        end
    end
    for _, v in pairs(opts) do tinsert(args, v) end
    request.multibulk(client, command, args)
end

local function zset_range_byscore_request(client, command, ...)
    local args, opts = {...}, { }
    if #args >= 1 and type(args[#args]) == 'table' then
        local options = table.remove(args, #args)
        if options.limit then
            tinsert(opts, 'LIMIT')
            tinsert(opts, options.limit.offset or options.limit[1])
            tinsert(opts, options.limit.count or options.limit[2])
        end
        if options.withscores then
            tinsert(opts, 'WITHSCORES')
        end
    end
    for _, v in pairs(opts) do
        tinsert(args, v)
    end
    request.multibulk(client, command, args)
end

local function zset_range_reply(reply, command, ...)
    local args = {...}
    local opts = args[4]
    if opts and (opts.withscores or string.lower(tostring(opts)) == 'withscores') then
        local new_reply = { }
        for i = 1, #reply, 2 do
            tinsert(new_reply, { reply[i], reply[i + 1] })
        end
        return new_reply
    end
    return reply
end

local function zset_store_request(client, command, ...)
    local args, opts = {...}, { }
    if #args >= 1 and type(args[#args]) == 'table' then
        local options = table.remove(args, #args)
        if options.weights and type(options.weights) == 'table' then
            tinsert(opts, 'WEIGHTS')
            for _, weight in ipairs(options.weights) do
                tinsert(opts, weight)
            end
        end
        if options.aggregate then
            tinsert(opts, 'AGGREGATE')
            tinsert(opts, options.aggregate)
        end
    end
    for _, v in pairs(opts) do
        tinsert(args, v)
    end
    request.multibulk(client, command, args)
end

local function mset_filter_args(client, command, ...)
    local args, arguments = {...}, {}
    if (#args == 1 and type(args[1]) == 'table') then
        for k,v in pairs(args[1]) do
            tinsert(arguments, k)
            tinsert(arguments, v)
        end
    else
        arguments = args
    end
    request.multibulk(client, command, arguments)
end

local function hash_multi_request_builder(builder_callback)
    return function(client, command, ...)
        local args, arguments = {...}, { }
        if #args == 2 then
            tinsert(arguments, args[1])
            for k, v in pairs(args[2]) do
                builder_callback(arguments, k, v)
            end
        else
            arguments = args
        end
        request.multibulk(client, command, arguments)
    end
end

local function parse_info(response)
    local info = {}
    local current = info
    response:gsub('([^\r\n]*)\r\n', function(kv)
        if kv == '' then return end
        local section = kv:match('^# (%w+)$')
        if section then
            current = {}
            info[section:lower()] = current
            return
        end
        local k,v = kv:match(('([^:]*):([^:]*)'):rep(1))
        if k:match('db%d+') then
            current[k] = {}
            v:gsub(',', function(dbkv)
                local dbk,dbv = kv:match('([^:]*)=([^:]*)')
                current[k][dbk] = dbv
            end)
        else
            current[k] = v
        end
    end)
    return info
end

local function scan_request(client, command, ...)
    local args, req, params = {...}, { }, nil
    if command == 'SCAN' then
        tinsert(req, args[1])
        params = args[2]
    else
        tinsert(req, args[1])
        tinsert(req, args[2])
        params = args[3]
    end
    if params and params.match then
        tinsert(req, 'MATCH')
        tinsert(req, params.match)
    end
    if params and params.count then
        tinsert(req, 'COUNT')
        tinsert(req, params.count)
    end
    request.multibulk(client, command, req)
end

local zscan_response = function(reply, command, ...)
    local original, new = reply[2], { }
    for i = 1, #original, 2 do
        tinsert(new, { original[i], tonumber(original[i + 1]) })
    end
    reply[2] = new
    return reply
end

local hscan_response = function(reply, command, ...)
    local original, new = reply[2], { }
    for i = 1, #original, 2 do
        new[original[i]] = original[i + 1]
    end
    reply[2] = new
    return reply
end

-- ############################################################################

function request.raw(client, buffer)
    local bufferType = type(buffer)

    if bufferType == 'table' then
        client.network.write(client, table.concat(buffer))
    elseif bufferType == 'string' then
        client.network.write(client, buffer)
    else
        client.error('argument error: ' .. bufferType)
    end
end

function request.multibulk(client, command, ...)
    local args = {...}
    local argsn = #args
    local buffer = { true, true }

    if argsn == 1 and type(args[1]) == 'table' then
        argsn, args = #args[1], args[1]
    end

    buffer[1] = '*' .. tostring(argsn + 1) .. "\r\n"
    buffer[2] = '$' .. #command .. "\r\n" .. command .. "\r\n"

    local table_insert = tinsert
    for i = 1, argsn do
        local s_argument = tostring(args[i] or '')
        table_insert(buffer, '$' .. #s_argument .. "\r\n" .. s_argument .. "\r\n")
    end

    client.network.write(client, table.concat(buffer))
end

-- ############################################################################

local function custom(command, send, parse)
    command = string.upper(command)
    return function(client, ...)
        send(client, command, ...)
        local reply = response.read(client)

        if type(reply) == 'table' and reply.queued then
            reply.parser = parse
            return reply
        else
            if parse then
                return parse(reply, command, ...)
            end
            return reply
        end
    end
end

local function command(command, opts)
    if opts == nil or type(opts) == 'function' then
        return custom(command, request.multibulk, opts)
    else
        return custom(command, opts.request or request.multibulk, opts.response)
    end
end

local define_command_impl = function(target, name, opts)
    local opts = opts or {}
    target[string.lower(name)] = custom(
        opts.command or string.upper(name),
        opts.request or request.multibulk,
        opts.response or nil
    )
end

local undefine_command_impl = function(target, name)
    target[string.lower(name)] = nil
end

-- ############################################################################
local client_prototype = {}
client_prototype.raw_cmd = function(client, buffer)
    request.raw(client, buffer .. "\r\n")
    return response.read(client)
end

-- obsolete
client_prototype.define_command = function(client, name, opts)
    define_command_impl(client, name, opts)
end

-- obsolete
client_prototype.undefine_command = function(client, name)
    undefine_command_impl(client, name)
end

client_prototype.quit = function(client)
    request.multibulk(client, 'QUIT')
    client.network.socket:shutdown()
    return true
end

client_prototype.shutdown = function(client)
    request.multibulk(client, 'SHUTDOWN')
    client.network.socket:shutdown()
end

-- Command pipelining
client_prototype.pipeline = function(client, block)
    local requests, replies, parsers = {}, {}, {}
    local table_insert = tinsert
    local socket_write, socket_read = client.network.write, client.network.read

    client.network.write = function(_, buffer)
        table_insert(requests, buffer)
    end

    -- TODO: this hack is necessary to temporarily reuse the current
    --       request -> response handling implementation of redis-lua
    --       without further changes in the code, but it will surely
    --       disappear when the new command-definition infrastructure
    --       will finally be in place.
    client.network.read = function() return '+QUEUED' end

    local pipeline = setmetatable({}, {
        __index = function(env, name)
            local cmd = client[name]
            if not cmd then
                client.error('unknown redis command: ' .. name, 2)
            end
            return function(self, ...)
                local reply = cmd(client, ...)
                table_insert(parsers, #requests, reply.parser)
                return reply
            end
        end
    })

    local success, retval = pcall(block, pipeline)

    client.network.write, client.network.read = socket_write, socket_read
    if not success then client.error(retval, 0) end

    client.network.write(client, table.concat(requests, ''))

    for i = 1, #requests do
        local reply, parser = response.read(client), parsers[i]
        if parser then
            reply = parser(reply)
        end
        table_insert(replies, i, reply)
    end

    return replies, #requests
end

-- Publish/Subscribe
do
    local channels = function(channels)
        if type(channels) == 'string' then
            channels = { channels }
        end
        return channels
    end

    local subscribe = function(client, ...)
        request.multibulk(client, 'subscribe', ...)
    end
    local psubscribe = function(client, ...)
        request.multibulk(client, 'psubscribe', ...)
    end
    local unsubscribe = function(client, ...)
        request.multibulk(client, 'unsubscribe')
    end
    local punsubscribe = function(client, ...)
        request.multibulk(client, 'punsubscribe')
    end

    local consumer_loop = function(client)
        local aborting, subscriptions = false, 0

        local abort = function()
            if not aborting then
                unsubscribe(client)
                punsubscribe(client)
                aborting = true
            end
        end

        return coroutine.wrap(function()
            while true do
                local message
                local response = response.read(client)

                if response[1] == 'pmessage' then
                    message = {
                        kind    = response[1],
                        pattern = response[2],
                        channel = response[3],
                        payload = response[4],
                    }
                else
                    message = {
                        kind    = response[1],
                        channel = response[2],
                        payload = response[3],
                    }
                end

                if string.match(message.kind, '^p?subscribe$') then
                    subscriptions = subscriptions + 1
                end
                if string.match(message.kind, '^p?unsubscribe$') then
                    subscriptions = subscriptions - 1
                end

                if aborting and subscriptions == 0 then
                    break
                end
                coroutine.yield(message, abort)
            end
        end)
    end

    client_prototype.pubsub = function(client, subscriptions)
        if type(subscriptions) == 'table' then
            if subscriptions.subscribe then
                subscribe(client, channels(subscriptions.subscribe))
            end
            if subscriptions.psubscribe then
                psubscribe(client, channels(subscriptions.psubscribe))
            end
        end
        return consumer_loop(client)
    end
end

-- Redis transactions (MULTI/EXEC)
do
    local function identity(...) return ... end
    local emptytable = {}

    local function initialize_transaction(client, options, block, queued_parsers)
        local table_insert = tinsert
        local coro = coroutine.create(block)

        if options.watch then
            local watch_keys = {}
            for _, key in pairs(options.watch) do
                table_insert(watch_keys, key)
            end
            if #watch_keys > 0 then
                client:watch(tunpack(watch_keys))
            end
        end

        local transaction_client = setmetatable({}, {__index=client})
        transaction_client.exec  = function(...)
            client.error('cannot use EXEC inside a transaction block')
        end
        transaction_client.multi = function(...)
            coroutine.yield()
        end
        transaction_client.commands_queued = function()
            return #queued_parsers
        end

        assert(coroutine.resume(coro, transaction_client))

        transaction_client.multi = nil
        transaction_client.discard = function(...)
            local reply = client:discard()
            for i, v in pairs(queued_parsers) do
                queued_parsers[i]=nil
            end
            coro = initialize_transaction(client, options, block, queued_parsers)
            return reply
        end
        transaction_client.watch = function(...)
            client.error('WATCH inside MULTI is not allowed')
        end
        setmetatable(transaction_client, { __index = function(t, k)
                local cmd = client[k]
                if type(cmd) == "function" then
                    local function queuey(self, ...)
                        local reply = cmd(client, ...)
                        assert((reply or emptytable).queued == true, 'a QUEUED reply was expected')
                        table_insert(queued_parsers, reply.parser or identity)
                        return reply
                    end
                    t[k]=queuey
                    return queuey
                else
                    return cmd
                end
            end
        })
        client:multi()
        return coro
    end

    local function transaction(client, options, coroutine_block, attempts)
        local queued_parsers, replies = {}, {}
        local retry = tonumber(attempts) or tonumber(options.retry) or 2
        local coro = initialize_transaction(client, options, coroutine_block, queued_parsers)

        local success, retval
        if coroutine.status(coro) == 'suspended' then
            success, retval = coroutine.resume(coro)
        else
            -- do not fail if the coroutine has not been resumed (missing t:multi() with CAS)
            success, retval = true, 'empty transaction'
        end
        if #queued_parsers == 0 or not success then
            client:discard()
            assert(success, retval)
            return replies, 0
        end

        local raw_replies = client:exec()
        if not raw_replies then
            if (retry or 0) <= 0 then
                client.error("MULTI/EXEC transaction aborted by the server")
            else
                --we're not quite done yet
                return transaction(client, options, coroutine_block, retry - 1)
            end
        end

        local table_insert = tinsert
        for i, parser in pairs(queued_parsers) do
            table_insert(replies, i, parser(raw_replies[i]))
        end

        return replies, #queued_parsers
    end

    client_prototype.transaction = function(client, arg1, arg2)
        local options, block
        if not arg2 then
            options, block = {}, arg1
        elseif arg1 then --and arg2, implicitly
            options, block = type(arg1)=="table" and arg1 or { arg1 }, arg2
        else
            client.error("Invalid parameters for redis transaction.")
        end

        if not options.watch then
            local watch_keys = { }
            for i, v in pairs(options) do
                if tonumber(i) then
                    tinsert(watch_keys, v)
                    options[i] = nil
                end
            end
            options.watch = watch_keys
        elseif not (type(options.watch) == 'table') then
            options.watch = { options.watch }
        end

        if not options.cas then
            local tx_block = block
            block = function(client, ...)
                client:multi()
                return tx_block(client, ...) --can't wrap this in pcall because we're in a coroutine.
            end
        end

        return transaction(client, options, block)
    end
end

-- MONITOR context
do
    local monitor_loop = function(client)
        local monitoring = true

        -- Tricky since the payload format changed starting from Redis 2.6.
        local pattern = '^(%d+%.%d+)( ?.- ?) ?"(%a+)" ?(.-)$'

        local abort = function()
            monitoring = false
        end

        return coroutine.wrap(function()
            client:monitor()

            while monitoring do
                local message, matched
                local response = response.read(client)

                local ok = response:gsub(pattern, function(time, info, cmd, args)
                    message = {
                        timestamp = tonumber(time),
                        client    = info:match('%d+.%d+.%d+.%d+:%d+'),
                        database  = tonumber(info:match('%d+')) or 0,
                        command   = cmd,
                        arguments = args:match('.+'),
                    }
                    matched = true
                end)

                if not matched then
                    client.error('Unable to match MONITOR payload: '..response)
                end

                coroutine.yield(message, abort)
            end
        end)
    end

    client_prototype.monitor_messages = function(client)
        return monitor_loop(client)
    end
end

-- ############################################################################
function redis.error(message, level)
    error(message, (level or 1) + 1)
end

function redis.command(cmd, opts)
    return command(cmd, opts)
end

-- obsolete
function redis.define_command(name, opts)
    define_command_impl(redis.commands, name, opts)
end

-- obsolete
function redis.undefine_command(name)
    undefine_command_impl(redis.commands, name)
end

-- commands operating on the key space
redis.commands = {
    exists           = command('EXISTS', {
        response = _toboolean
    }),
    del              = command('DEL'),
    type             = command('TYPE'),
    rename           = command('RENAME'),
    renamenx         = command('RENAMENX', {
        response = _toboolean
    }),
    expire           = command('EXPIRE', {
        response = _toboolean
    }),
    pexpire          = command('PEXPIRE', {     -- >= 2.6
        response = _toboolean
    }),
    expireat         = command('EXPIREAT', {
        response = _toboolean
    }),
    pexpireat        = command('PEXPIREAT', {   -- >= 2.6
        response = _toboolean
    }),
    ttl              = command('TTL'),
    pttl             = command('PTTL'),         -- >= 2.6
    move             = command('MOVE', {
        response = _toboolean
    }),
    dbsize           = command('DBSIZE'),
    persist          = command('PERSIST', {     -- >= 2.2
        response = _toboolean
    }),
    keys             = command('KEYS', {
        response = function(response)
            if type(response) == 'string' then
                -- backwards compatibility path for Redis < 2.0
                local keys = {}
                response:gsub('[^%s]+', function(key)
                    tinsert(keys, key)
                end)
                response = keys
            end
            return response
        end
    }),
    randomkey        = command('RANDOMKEY'),
    sort             = command('SORT', {
        request = sort_request,
    }),
    scan             = command('SCAN', {        -- >= 2.8
        request = scan_request,
    }),

    -- commands operating on string values
    set              = command('SET'),
    setnx            = command('SETNX', {
        response = _toboolean
    }),
    setex            = command('SETEX'),        -- >= 2.0
    psetex           = command('PSETEX'),       -- >= 2.6
    mset             = command('MSET', {
        request = mset_filter_args
    }),
    msetnx           = command('MSETNX', {
        request  = mset_filter_args,
        response = _toboolean
    }),
    get              = command('GET'),
    mget             = command('MGET'),
    getset           = command('GETSET'),
    incr             = command('INCR'),
    incrby           = command('INCRBY'),
    incrbyfloat      = command('INCRBYFLOAT', { -- >= 2.6
        response = function(reply, command, ...)
            return tonumber(reply)
        end,
    }),
    decr             = command('DECR'),
    decrby           = command('DECRBY'),
    append           = command('APPEND'),       -- >= 2.0
    substr           = command('SUBSTR'),       -- >= 2.0
    strlen           = command('STRLEN'),       -- >= 2.2
    setrange         = command('SETRANGE'),     -- >= 2.2
    getrange         = command('GETRANGE'),     -- >= 2.2
    setbit           = command('SETBIT'),       -- >= 2.2
    getbit           = command('GETBIT'),       -- >= 2.2
    bitop            = command('BITOP'),        -- >= 2.6
    bitcount         = command('BITCOUNT'),     -- >= 2.6

    -- commands operating on lists
    rpush            = command('RPUSH'),
    lpush            = command('LPUSH'),
    llen             = command('LLEN'),
    lrange           = command('LRANGE'),
    ltrim            = command('LTRIM'),
    lindex           = command('LINDEX'),
    lset             = command('LSET'),
    lrem             = command('LREM'),
    lpop             = command('LPOP'),
    rpop             = command('RPOP'),
    rpoplpush        = command('RPOPLPUSH'),
    blpop            = command('BLPOP'),        -- >= 2.0
    brpop            = command('BRPOP'),        -- >= 2.0
    rpushx           = command('RPUSHX'),       -- >= 2.2
    lpushx           = command('LPUSHX'),       -- >= 2.2
    linsert          = command('LINSERT'),      -- >= 2.2
    brpoplpush       = command('BRPOPLPUSH'),   -- >= 2.2

    -- commands operating on sets
    sadd             = command('SADD'),
    srem             = command('SREM'),
    spop             = command('SPOP'),
    smove            = command('SMOVE', {
        response = _toboolean
    }),
    scard            = command('SCARD'),
    sismember        = command('SISMEMBER', {
        response = _toboolean
    }),
    sinter           = command('SINTER'),
    sinterstore      = command('SINTERSTORE'),
    sunion           = command('SUNION'),
    sunionstore      = command('SUNIONSTORE'),
    sdiff            = command('SDIFF'),
    sdiffstore       = command('SDIFFSTORE'),
    smembers         = command('SMEMBERS'),
    srandmember      = command('SRANDMEMBER'),
    sscan            = command('SSCAN', {       -- >= 2.8
        request = scan_request,
    }),

    -- commands operating on sorted sets
    zadd             = command('ZADD'),
    zincrby          = command('ZINCRBY', {
        response = function(reply, command, ...)
            return tonumber(reply)
        end,
    }),
    zrem             = command('ZREM'),
    zrange           = command('ZRANGE', {
        request  = zset_range_request,
        response = zset_range_reply,
    }),
    zrevrange        = command('ZREVRANGE', {
        request  = zset_range_request,
        response = zset_range_reply,
    }),
    zrangebyscore    = command('ZRANGEBYSCORE', {
        request  = zset_range_byscore_request,
        response = zset_range_reply,
    }),
    zrevrangebyscore = command('ZREVRANGEBYSCORE', {    -- >= 2.2
        request  = zset_range_byscore_request,
        response = zset_range_reply,
    }),
    zunionstore      = command('ZUNIONSTORE', {         -- >= 2.0
        request = zset_store_request
    }),
    zinterstore      = command('ZINTERSTORE', {         -- >= 2.0
        request = zset_store_request
    }),
    zcount           = command('ZCOUNT'),
    zcard            = command('ZCARD'),
    zscore           = command('ZSCORE'),
    zremrangebyscore = command('ZREMRANGEBYSCORE'),
    zrank            = command('ZRANK'),                -- >= 2.0
    zrevrank         = command('ZREVRANK'),             -- >= 2.0
    zremrangebyrank  = command('ZREMRANGEBYRANK'),      -- >= 2.0
    zscan            = command('ZSCAN', {               -- >= 2.8
        request  = scan_request,
        response = zscan_response,
    }),

    -- commands operating on hashes
    hset             = command('HSET', {        -- >= 2.0
        response = _toboolean
    }),
    hsetnx           = command('HSETNX', {      -- >= 2.0
        response = _toboolean
    }),
    hmset            = command('HMSET', {       -- >= 2.0
        request  = hash_multi_request_builder(function(args, k, v)
            tinsert(args, k)
            tinsert(args, v)
        end),
    }),
    hincrby          = command('HINCRBY'),      -- >= 2.0
    hincrbyfloat     = command('HINCRBYFLOAT', {-- >= 2.6
        response = function(reply, command, ...)
            return tonumber(reply)
        end,
    }),
    hget             = command('HGET'),         -- >= 2.0
    hmget            = command('HMGET', {       -- >= 2.0
        request  = hash_multi_request_builder(function(args, k, v)
            tinsert(args, v)
        end),
    }),
    hdel             = command('HDEL'),        -- >= 2.0
    hexists          = command('HEXISTS', {     -- >= 2.0
        response = _toboolean
    }),
    hlen             = command('HLEN'),         -- >= 2.0
    hkeys            = command('HKEYS'),        -- >= 2.0
    hvals            = command('HVALS'),        -- >= 2.0
    hgetall          = command('HGETALL', {     -- >= 2.0
        response = function(reply, command, ...)
            local new_reply = { }
            for i = 1, #reply, 2 do new_reply[reply[i]] = reply[i + 1] end
            return new_reply
        end
    }),
    hscan            = command('HSCAN', {       -- >= 2.8
        request  = scan_request,
        response = hscan_response,
    }),

    -- connection related commands
    ping             = command('PING', {
        response = function(response) return response == 'PONG' end
    }),
    echo             = command('ECHO'),
    auth             = command('AUTH'),
    select           = command('SELECT'),

    -- transactions
    multi            = command('MULTI'),        -- >= 2.0
    exec             = command('EXEC'),         -- >= 2.0
    discard          = command('DISCARD'),      -- >= 2.0
    watch            = command('WATCH'),        -- >= 2.2
    unwatch          = command('UNWATCH'),      -- >= 2.2

    -- publish - subscribe
    subscribe        = command('SUBSCRIBE'),    -- >= 2.0
    unsubscribe      = command('UNSUBSCRIBE'),  -- >= 2.0
    psubscribe       = command('PSUBSCRIBE'),   -- >= 2.0
    punsubscribe     = command('PUNSUBSCRIBE'), -- >= 2.0
    publish          = command('PUBLISH'),      -- >= 2.0

    -- redis scripting
    eval             = command('EVAL'),         -- >= 2.6
    evalsha          = command('EVALSHA'),      -- >= 2.6
    script           = command('SCRIPT'),       -- >= 2.6

    -- remote server control commands
    bgrewriteaof     = command('BGREWRITEAOF'),
    config           = command('CONFIG', {     -- >= 2.0
        response = function(reply, command, ...)
            if (type(reply) == 'table') then
                local new_reply = { }
                for i = 1, #reply, 2 do new_reply[reply[i]] = reply[i + 1] end
                return new_reply
            end

            return reply
        end
    }),
    client           = command('CLIENT'),       -- >= 2.4
    slaveof          = command('SLAVEOF'),
    save             = command('SAVE'),
    bgsave           = command('BGSAVE'),
    lastsave         = command('LASTSAVE'),
    flushdb          = command('FLUSHDB'),
    flushall         = command('FLUSHALL'),
    monitor          = command('MONITOR'),
    time             = command('TIME'),         -- >= 2.6
    slowlog          = command('SLOWLOG', {     -- >= 2.2.13
        response = function(reply, command, ...)
            if (type(reply) == 'table') then
                local structured = { }
                for index, entry in ipairs(reply) do
                    structured[index] = {
                        id = tonumber(entry[1]),
                        timestamp = tonumber(entry[2]),
                        duration = tonumber(entry[3]),
                        command = entry[4],
                    }
                end
                return structured
            end

            return reply
        end
    }),
    info             = command('INFO', {
        response = parse_info,
    }),
}

return RedisDB
