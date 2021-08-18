--redis.lua
local Socket        = import("driver/socket.lua")
local QueueFIFO     = import("container/queue_fifo.lua")

local ipairs        = ipairs
local tonumber      = tonumber
local log_err       = logger.err
local log_info      = logger.info
local ssub          = string.sub
local sbyte         = string.byte
local sgsub         = string.gsub
local supper        = string.upper
local sformat       = string.format
local sgmatch       = string.gmatch
local tinsert       = table.insert
local tunpack       = table.unpack
local tpack         = table.pack

local NetwkTime     = enum("NetwkTime")
local KernCode      = enum("KernCode")
local SUCCESS       = KernCode.SUCCESS
local REDIS_FAILED  = KernCode.REDIS_FAILED
local DB_TIMEOUT    = NetwkTime.DB_CALL_TIMEOUT

local LineTitle     = "\r\n"

local event_mgr     = quanta.get("event_mgr")
local update_mgr    = quanta.get("update_mgr")
local thread_mgr    = quanta.get("thread_mgr")

local subscribe_commands = {
    subscribe       = { cmd = "SUBSCRIBE"   },  -- >= 2.0
    unsubscribe     = { cmd = "UNSUBSCRIBE" },  -- >= 2.0
    psubscribe      = { cmd = "PSUBSCRIBE"  },  -- >= 2.0
    punsubscribe    = { cmd = "PUNSUBSCRIBE"},  -- >= 2.0
}

local redis_commands = {
    del         = { cmd = "DEL"     },
    set         = { cmd = "SET"     },
    type        = { cmd = "TYPE"    },
    rename      = { cmd = "RENAME"  },
    ttl         = { cmd = "TTL"     },
    dbsize      = { cmd = "DBSIZE"  },
    pttl        = { cmd = "PTTL"    },      -- >= 2.6
    setex       = { cmd = "SETEX"   },      -- >= 2.0
    psetex      = { cmd = "PSETEX"  },      -- >= 2.6
    get         = { cmd = "GET"     },
    mget        = { cmd = "MGET"    },
    getset      = { cmd = "GETSET"  },
    incr        = { cmd = "INCR"    },
    incrby      = { cmd = "INCRBY"  },
    decr        = { cmd = "DECR"    },
    decrby      = { cmd = "DECRBY"  },
    append      = { cmd = "APPEND"  },      -- >= 2.0
    substr      = { cmd = "SUBSTR"  },      -- >= 2.0
    strlen      = { cmd = "STRLEN"  },      -- >= 2.2
    setrange    = { cmd = "SETRANGE"},      -- >= 2.2
    getrange    = { cmd = "GETRANGE"},      -- >= 2.2
    setbit      = { cmd = "SETBIT"  },      -- >= 2.2
    getbit      = { cmd = "GETBIT"  },      -- >= 2.2
    bitop       = { cmd = "BITOP"   },      -- >= 2.6
    bitcount    = { cmd = "BITCOUNT"},      -- >= 2.6
    rpush       = { cmd = "RPUSH"   },
    lpush       = { cmd = "LPUSH"   },
    llen        = { cmd = "LLEN"    },
    lrange      = { cmd = "LRANGE"  },
    ltrim       = { cmd = "LTRIM"   },
    lindex      = { cmd = "LINDEX"  },
    lset        = { cmd = "LSET"    },
    lrem        = { cmd = "LREM"    },
    lpop        = { cmd = "LPOP"    },
    rpop        = { cmd = "RPOP"    },
    blpop       = { cmd = "BLPOP"   },      -- >= 2.0
    brpop       = { cmd = "BRPOP"   },      -- >= 2.0
    rpushx      = { cmd = "RPUSHX"  },      -- >= 2.2
    lpushx      = { cmd = "LPUSHX"  },      -- >= 2.2
    linsert     = { cmd = "LINSERT" },      -- >= 2.2
    sadd        = { cmd = "SADD"    },
    srem        = { cmd = "SREM"    },
    spop        = { cmd = "SPOP"    },
    scard       = { cmd = "SCARD"   },
    sinter      = { cmd = "SINTER"  },
    sunion      = { cmd = "SUNION"  },
    sdiff       = { cmd = "SDIFF"   },
    zadd        = { cmd = "ZADD"    },
    zrem        = { cmd = "ZREM"    },
    zcount      = { cmd = "ZCOUNT"  },
    zcard       = { cmd = "ZCARD"   },
    zscore      = { cmd = "ZSCORE"  },
    zrank       = { cmd = "ZRANK"   },      -- >= 2.0
    zrevrank    = { cmd = "ZREVRANK"},      -- >= 2.0
    hget        = { cmd = "HGET"    },      -- >= 2.0
    hincrby     = { cmd = "HINCRBY" },      -- >= 2.0
    hdel        = { cmd = "HDEL"    },      -- >= 2.0
    hlen        = { cmd = "HLEN"    },      -- >= 2.0
    hkeys       = { cmd = "HKEYS"   },      -- >= 2.0
    hvals       = { cmd = "HVALS"   },      -- >= 2.0
    echo        = { cmd = "ECHO"    },
    select      = { cmd = "SELECT"  },
    multi       = { cmd = "MULTI"   },      -- >= 2.0
    exec        = { cmd = "EXEC"    },      -- >= 2.0
    discard     = { cmd = "DISCARD" },      -- >= 2.0
    watch       = { cmd = "WATCH"   },      -- >= 2.2
    unwatch     = { cmd = "UNWATCH" },      -- >= 2.2
    eval        = { cmd = "EVAL"    },      -- >= 2.6
    evalsha     = { cmd = "EVALSHA" },      -- >= 2.6
    script      = { cmd = "SCRIPT"  },      -- >= 2.6
    time        = { cmd = "TIME"    },      -- >= 2.6
    client      = { cmd = "CLIENT"  },      -- >= 2.4
    slaveof     = { cmd = "SLAVEOF" },
    save        = { cmd = "SAVE"    },
    bgsave      = { cmd = "BGSAVE"  },
    lastsave    = { cmd = "LASTSAVE"},
    flushdb     = { cmd = "FLUSHDB" },
    flushall    = { cmd = "FLUSHALL"},
    monitor     = { cmd = "MONITOR" },
    hmset       = { cmd = "HMSET"   },      -- >= 2.0
    hmget       = { cmd = "HMGET"   },      -- >= 2.0
    hscan       = { cmd = "HSCAN"   },      -- >= 2.8
    sort        = { cmd = "SORT"    },
    scan        = { cmd = "SCAN"    },      -- >= 2.8
    mset        = { cmd = "MSET"    },
    sscan       = { cmd = "SSCAN"   },      -- >= 2.8
    publish     = { cmd = "PUBLISH"     },  -- >= 2.0
    sinterstore = { cmd = "SINTERSTORE" },
    sunionstore = { cmd = "SUNIONSTORE" },
    sdiffstore  = { cmd = "SDIFFSTORE"  },
    smembers    = { cmd = "SMEMBERS"    },
    srandmember = { cmd = "SRANDMEMBER" },
    rpoplpush   = { cmd = "RPOPLPUSH"   },
    randomkey   = { cmd = "RANDOMKEY"   },
    brpoplpush  = { cmd = "BRPOPLPUSH"  },  -- >= 2.2
    bgrewriteaof= { cmd = "BGREWRITEAOF"},
    zscan       = { cmd = "ZSCAN"       },  -- >= 2.8
    zrange      = { cmd = "ZRANGE",     },
    zrevrange   = { cmd = "ZREVRANGE"   },
    zrangebyscore   = { cmd = "ZRANGEBYSCORE"       },
    zrevrangebyscore= { cmd = "ZREVRANGEBYSCORE"    },  -- >= 2.2
    zunionstore     = { cmd = "ZUNIONSTORE"         },  -- >= 2.0
    zinterstore     = { cmd = "ZINTERSTORE"         },  -- >= 2.0
    zremrangebyscore= { cmd = "ZREMRANGEBYSCORE"    },
    zremrangebyrank = { cmd = "ZREMRANGEBYRANK"     },  -- >= 2.0
    zincrby         = { cmd = "ZINCRBY",        convertor = tonumber    },
    incrbyfloat     = { cmd = "INCRBYFLOAT",    convertor = tonumber    },
    hincrbyfloat    = { cmd = "HINCRBYFLOAT",   convertor = tonumber    },  -- >= 2.6
    setnx           = { cmd = "SETNX",          convertor = _toboolean  },
    exists          = { cmd = "EXISTS",         convertor = _toboolean  },
    renamenx        = { cmd = "RENAMENX",       convertor = _toboolean  },
    expire          = { cmd = "EXPIRE",         convertor = _toboolean  },
    pexpire         = { cmd = "PEXPIRE",        convertor = _toboolean  },  -- >= 2.6
    expireat        = { cmd = "EXPIREAT",       convertor = _toboolean  },
    pexpireat       = { cmd = "PEXPIREAT",      convertor = _toboolean  },  -- >= 2.6
    move            = { cmd = "MOVE",           convertor = _toboolean  },
    persist         = { cmd = "PERSIST",        convertor = _toboolean  },  -- >= 2.2
    smove           = { cmd = "SMOVE",          convertor = _toboolean  },
    sismember       = { cmd = "SISMEMBER",      convertor = _toboolean  },
    hset            = { cmd = "HSET",           convertor = _toboolean  },  -- >= 2.0
    hsetnx          = { cmd = "HSETNX",         convertor = _toboolean  },  -- >= 2.0
    hexists         = { cmd = "HEXISTS",        convertor = _toboolean  },  -- >= 2.0
    msetnx          = { cmd = "MSETNX",         convertor = _toboolean  },
    hgetall         = { cmd = "HGETALL",        convertor = _tomap      },  -- >= 2.0
    config          = { cmd = "CONFIG",         convertor = _tomap      },  -- >= 2.0
    keys            = { cmd = "KEYS",           convertor = _tokeys     },
}

local function _async_call(sessions, quote)
    local session_id = thread_mgr:build_session_id()
    sessions:push(session_id)
    return thread_mgr:yield(session_id, quote, DB_TIMEOUT)
end

local _redis_resp_parser = {
    ["+"] = function(sessions, body)
        --simple string
        return true, body
    end,
    ["-"] = function(sessions, body)
        -- error reply
        return false, body
    end,
    [":"] = function(sessions, body)
        -- integer reply
        return true, tonumber(body)
    end,
    ["$"] = function(sessions, body)
        -- bulk string
        if tonumber(body) < 0 then
            return true, nil
        end
        return _async_call(sessions, "redis parse bulk string")
    end,
    ["*"] = function(sessions, body)
        -- array
        local length = tonumber(body)
        if length < 0 then
            return true, nil
        end
        local array = {}
        local noerr = true
        for i = 1, length do
            local ok, value = _async_call(sessions, "redis parse array")
            if not ok then
                noerr = false
            end
            array[i] = value
        end
        return noerr, array
    end
}

local _redis_subscribe_replys = {
    message = function(self, channel, data)
        log_info("[RedisDB][_redis_subscribe_replys] subscribe message channel(%s) data: %s", channel, data)
        event_mgr:notify_trigger("on_redis_subscribe", channel, data)
    end,
    pmessage = function(self, channel, data, date2)
        log_info("[RedisDB][_redis_subscribe_replys] psubscribe pmessage channel(%s) data: %s, data2: %s", channel, data, date2)
        event_mgr:notify_trigger("on_redis_psubscribe", channel, data, date2)
    end,
    subscribe = function(self, channel, status)
        log_info("[RedisDB][_redis_subscribe_replys] subscribe redis channel(%s) status: %s", channel, status)
        self.subscribes[channel] = true
    end,
    psubscribe = function(self, channel, status)
        log_info("[RedisDB][_redis_subscribe_replys] psubscribe redis channel(%s) status: %s", channel, status)
        self.psubscribes[channel] = true
    end,
    unsubscribe = function(self, channel, status)
        log_info("[RedisDB][_redis_subscribe_replys] unsubscribe redis channel(%s) status: %s", channel, status)
        self.subscribes[channel] = nil
    end,
    punsubscribe = function(self, channel, status)
        log_info("[RedisDB][_redis_subscribe_replys] punsubscribe redis channel(%s) status: %s", channel, status)
        self.psubscribes[channel] = nil
    end
}

local function _compose_bulk_string(value)
    if not value then
        return "\r\n$-1"
    end
    if type(value) ~= "string" then
        value = tostring(value)
    end
    return sformat("\r\n$%d\r\n%s", #value, value)
end

local function _compose_array(cmd, array)
    local count = 0
    if array then
        count = (array.n or #array)
    end
    local buff = sformat("*%d%s", count + 1, _compose_bulk_string(cmd))
    if count > 0 then
        for i = 1, count do
            buff = sformat("%s%s", buff, _compose_bulk_string(array[i]))
        end
    end
    return sformat("%s\r\n", buff)
end

local function _compose_message(cmd, msg)
    if not msg then
        return _compose_array(cmd)
    end
    if type(msg) == "table" then
        return _compose_array(cmd, msg)
    end
    return _compose_array(cmd, { msg })
end

local function _ispeng(value)
    return value == "PONG"
end

local function _tokeys(value)
    if type(value) == 'string' then
        -- backwards compatibility path for Redis < 2.0
        local keys = {}
        sgsub(value, '[^%s]+', function(key)
            tinsert(keys, key)
        end)
        return keys
    end
    return value
end

local function _tomap(value)
    if (type(value) == 'table') then
        local new_value = { }
        for i = 1, #value, 2 do 
            new_value[value[i]] = value[i + 1] 
        end
        return new_value
    end
    return value
end
    
local function _toboolean(value)
    if value == '1' or value == 'true' or value == 'TRUE' then
        return true
    elseif value == '0' or value == 'false' or value == 'FALSE' then
        return false
    end
    return nil
end

local RedisDB = class()
local prop = property(RedisDB)
prop:reader("ip", nil)          --redis地址
prop:reader("sock", nil)        --网络连接对象
prop:reader("ssock", nil)       --网络连接对象
prop:reader("index", "")        --db index
prop:reader("port", 6379)       --redis端口
prop:reader("passwd", nil)      --passwd
prop:reader("sessions", nil)    --sessions
prop:reader("ssessions", nil)   --ssessions
prop:reader("subscribes", {})   --subscribes
prop:reader("psubscribes", {})  --psubscribes

function RedisDB:__init(conf)
    self.ip = conf.host
    self.port = conf.port
    self.passwd = conf.passwd
    self.index = conf.db
    self.sessions = QueueFIFO()
    self.ssessions = QueueFIFO()
    --update
    update_mgr:attach_hour(self)
    update_mgr:attach_second(self)
    --setup
    self:setup()
end

function RedisDB:__release()
    self:close()
end

function RedisDB:setup()
    for cmd, param in pairs(redis_commands) do
        RedisDB[cmd] = function(self, ...)
            return self:commit(self.sock, param, ...)
        end
    end
    for cmd, param in pairs(subscribe_commands) do
        RedisDB[cmd] = function(self, ...)
            return self:commit(self.ssock, param, ...)
        end
    end
end

function RedisDB:close()
    if self.sock then
        self.sessions:clear()
        self.sock:close()
        self.sock = nil
    end
    if self.ssock then
        self.ssessions:clear()
        self.ssock:close()
        self.ssock = nil
    end
end

function RedisDB:login(socket, title)
    if not socket:connect(self.ip, self.port) then
        log_err("[MysqlDB][login] connect %s db(%s:%s) failed!", title, self.ip, self.port)
        return false
    end
    if self.passwd then
        local ok, res = self:auth(socket)
        if not ok or res ~= "OK" then
            log_err("[RedisDB][login] auth %s db(%s:%s) failed! because: %s", title, self.ip, self.port, res)
            return false
        end
        log_info("[RedisDB][login] auth %s db(%s:%s) success!", title, self.ip, self.port)
    end
    if self.index then
        local ok, res = self:select(self.index)
        if not ok or res ~= "OK" then
            log_err("[RedisDB][login] select %s db(%s:%s-%s) failed! because: %s", title, self.ip, self.port, self.index, res)
            return false
        end
        log_info("[RedisDB][login] select %s db(%s:%s-%s) success!", title, self.ip, self.port, self.index)
    end
    return true
end

function RedisDB:on_hour()
    self:ping()
end

function RedisDB:on_second()
    if not self.sock then
        self.sock = Socket(self)
        if not self:login(self.sock, "query") then
            self.sock = nil
        end
    end
    if not self.ssock then
        self.ssock = Socket(self)
        if not self:login(self.ssock, "subcribe") then
            self.ssock = nil
            return
        end
        for channel in pairs(self.subscribes) do
            self:subscribe(channel)
        end
        for channel in pairs(self.psubscribes) do
            self:psubscribes(channel)
        end
    end
end

function RedisDB:on_socket_close(sock)
    if sock == self.sock then
        self.sessions:clear()
        self.sock = nil
    else
        self.ssessions:clear()
        self.ssock = nil
    end
end

function RedisDB:on_socket_recv(sock)
    while true do
        local line, length = sock:peek_line(LineTitle)
        if not line then
            break
        end
        sock:pop(length)
        thread_mgr:fork(function()
            local ok, res = true, line
            local cur_sessions = (sock == self.sock) and self.sessions or self.ssessions
            local session_id = cur_sessions:pop()
            local prefix, body = ssub(line, 1, 1), ssub(line, 2)
            local prefix_func = _redis_resp_parser[prefix]
            if prefix_func then
                ok, res = prefix_func(cur_sessions, body)
            end
            if ok and sock == self.ssock then
                self:on_suncribe_reply(res)
            end
            if session_id then
                thread_mgr:response(session_id, ok, res)
            end
        end)
    end
end

function RedisDB:on_suncribe_reply(res)
    if type(res) == "table" then
        local ttype, channel, data, data2 = res[1], res[2], res[3], res[4]
        local reply_func = _redis_subscribe_replys[ttype]
        if reply_func then
            reply_func(self, channel, data, data2)
        end
    end
end

function RedisDB:commit(sock, param, ...)
    if not sock then
        return false, "sock isn't connected"
    end
    local packet = _compose_message(param.cmd, tpack(...))
    if not sock:send(packet) then
        return false, "send request failed"
    end
    local cur_sessions = (sock == self.sock) and self.sessions or self.ssessions
    local ok, res = _async_call(cur_sessions, "redis commit")
    local convertor = param.convertor
    if ok and convertor then
        return ok, convertor(res)
    end
    return ok, res
end

function RedisDB:execute(cmd, ...)
    if RedisDB[cmd] then
        return self[cmd](self, ...)
    end
    return self:commit(self.sock, { cmd = supper(cmd) }, ...)
end

function RedisDB:ping()
    self.commit(self.sock, { cmd = "PING" })
    self.commit(self.ssock, { cmd = "PING" })
end

function RedisDB:auth(socket)
    return self:commit(socket, { cmd = "AUTH" }, self.passwd)
end

return RedisDB
