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

local update_mgr    = quanta.get("update_mgr")
local thread_mgr    = quanta.get("thread_mgr")

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
    auth        = { cmd = "AUTH"    },
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
    subscribe   = { cmd = "SUBSCRIBE"   },  -- >= 2.0
    unsubscribe = { cmd = "UNSUBSCRIBE" },  -- >= 2.0
    psubscribe  = { cmd = "PSUBSCRIBE"  },  -- >= 2.0
    punsubscribe= { cmd = "PUNSUBSCRIBE"},  -- >= 2.0
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
    ping            = { cmd = "PING",           convertor = _ispeng     },
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

local function _async_call(self, quote)
    local session_id = thread_mgr:build_session_id()
    self.sessions:push(session_id)
    return thread_mgr:yield(session_id, quote, DB_TIMEOUT * 2)
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
        return true, tonumber(body)
    end,
    ["$"] = function(self, body)
        -- bulk string
        if tonumber(body) < 0 then
            return true, nil
        end
        return _async_call(self, "redis parse bulk string")
    end,
    ["*"] = function(self, body)
        -- array
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
prop:reader("index", "")        --db index
prop:reader("port", 6379)       --redis端口
prop:reader("passwd", nil)      --passwd
prop:reader("sessions", nil)    --sessions

function RedisDB:__init(conf)
    self.ip = conf.host
    self.port = conf.port
    self.passwd = conf.passwd
    self.index = conf.db
    self.sessions = QueueFIFO()
    --attach_second
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
            local ok, res = self:commit(param.cmd, ...)
            local convertor = param.convertor
            if ok and convertor then
                return ok, convertor(res)
            end
            return ok, res
        end
    end
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
        local socket = Socket(self)
        if socket:connect(self.ip, self.port) then
            self.sock = socket
            if self.passwd then
                local ok, res = self:auth(self.passwd)
                if not ok or res ~= "OK" then
                    log_err("[RedisDB][on_second] auth db(%s:%s) failed! because: %s", self.ip, self.port, res)
                    self.sock = nil
                end
                log_info("[RedisDB][on_second] auth db(%s:%s) success!", self.ip, self.port)
            end
            if self.index then
                local ok, res = self:select(self.index)
                if not ok or res ~= "OK" then
                    log_err("[RedisDB][on_second] select db(%s:%s-%s) failed! because: %s", self.ip, self.port, self.index, res)
                    self.sock = nil
                end
                log_info("[RedisDB][on_second] select db(%s:%s-%s) success!", self.ip, self.port, self.index)
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
        local line, length = sock:peek_line(LineTitle)
        if not line then
            break
        end
        sock:pop(length)
        local session_id = self.sessions:pop()
        if session_id then
            thread_mgr:fork(function()
                local prefix, body = ssub(line, 1, 1), ssub(line, 2)
                local prefix_func = _redis_resp_parser[prefix]
                if prefix_func then
                    thread_mgr:response(session_id, prefix_func(self, body))
                    return
                end
                thread_mgr:response(session_id, true, line)
            end)
        end
    end
end

function RedisDB:commit(cmd, ...)
    local packet = _compose_message(supper(cmd), tpack(...))
    if not self.sock:send(packet) then
        return false, "send request failed"
    end
    return _async_call(self, "redis commit")
end

function RedisDB:execute(cmd, ...)
    if redis_commands[cmd] then
        return self[cmd](self, ...)
    end
    return self:commit(cmd, ...)
end

return RedisDB
