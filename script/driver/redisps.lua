--psredis.lua
local log_err       = logger.err
local tunpack       = table.unpack

local Redis         = import("driver/redis.lua")
local Socket        = import("driver/socket.lua")

local subscribe_commands = {
    subscribe       = { cmd = "SUBSCRIBE"   },  -- >= 2.0
    psubscribe      = { cmd = "PSUBSCRIBE"  },  -- >= 2.0
}

local unsubscribe_commands = {
    unsubscribe     = { cmd = "UNSUBSCRIBE" },  -- >= 2.0
    punsubscribe    = { cmd = "PUNSUBSCRIBE"},  -- >= 2.0
}

local _redis_subscribe_replys = {
    message = function(self, channel, data)
        if self.callbacks[channel] then
            self.callbacks[channel](channel, data)
        end
    end,
    pmessage = function(self, pattern, channel, data)
        if self.callbacks[channel] then
            self.callbacks[channel](channel, data)
        end
    end,
    subscribe = function(self, channel, status)
        self.subscribes[channel] = true
    end,
    psubscribe = function(self, channel, status)
        self.psubscribes[channel] = true
    end,
    unsubscribe = function(self, channel, status)
        self.subscribes[channel] = nil
    end,
    punsubscribe = function(self, channel, status)
        self.psubscribes[channel] = nil
    end
}

local PSRedis = class(Redis)
local prop = property(PSRedis)
prop:reader("executer", nil)
prop:reader("callbacks", {})
prop:reader("subscribes", {})
prop:reader("psubscribes", {})

function PSRedis:__init(conf)
    self.subscrible = true
    self:setup_command()
end

function PSRedis:setup_command()
    for cmd, param in pairs(subscribe_commands) do
        PSRedis[cmd] = function(this, callback, channel)
            if self.callbacks[channel] then
                return true
            end
            self.callbacks[channel] = callback
            if self.executer then
                return this:commit(self.executer, param, channel)
            end
            return false, "db not connected"
        end
    end
    for cmd, param in pairs(unsubscribe_commands) do
        PSRedis[cmd] = function(this, channel)
            if self.executer then
                return this:commit(self.executer, param, channel)
            end
            return false, "db not connected"
        end
    end
end

function PSRedis:setup_pool(hosts)
    if not next(hosts) then
        log_err("[PSRedis][setup_pool] redis config err: hosts is empty")
        return
    end
    for _, host in pairs(hosts) do
        local socket = Socket(self, host[1], host[2])
        self.connections[1] = socket
        socket:set_id(1)
        break
    end
end

function PSRedis:on_socket_alive(sock)
    self.executer = sock
    for channel in pairs(self.subscribes) do
        self:commit(sock, "subscribe", channel)
    end
    for channel in pairs(self.psubscribes) do
        self:commit(sock, "psubscribes", channel)
    end
end

function PSRedis:do_socket_recv(res)
    if type(res) == "table" then
        local ttype, channel, data, data2 = tunpack(res)
        local reply_func = _redis_subscribe_replys[ttype]
        if reply_func then
            reply_func(self, channel, data, data2)
        end
    end
end

return PSRedis
