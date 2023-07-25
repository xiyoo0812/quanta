--psredis.lua
local log_err       = logger.err
local tunpack       = table.unpack

local event_mgr     = quanta.get("event_mgr")

local Redis         = import("driver/redis.lua")
local Socket        = import("driver/socket.lua")
local QueueFIFO     = import("container/queue_fifo.lua")

local subscribe_commands = {
    subscribe       = { cmd = "SUBSCRIBE"   },  -- >= 2.0
    unsubscribe     = { cmd = "UNSUBSCRIBE" },  -- >= 2.0
    psubscribe      = { cmd = "PSUBSCRIBE"  },  -- >= 2.0
    punsubscribe    = { cmd = "PUNSUBSCRIBE"},  -- >= 2.0
}

local _redis_subscribe_replys = {
    message = function(self, channel, data)
        event_mgr:notify_trigger("on_subscribe_ready", channel, data)
    end,
    pmessage = function(self, channel, data, date2)
        event_mgr:notify_trigger("on_psubscribe_ready", channel, data, date2)
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
prop:reader("subscribes", {})
prop:reader("psubscribes", {})

function PSRedis:__init(conf, id)
end

function PSRedis:setup_command()
    for cmd, param in pairs(subscribe_commands) do
        PSRedis[cmd] = function(this, ...)
            return this:commit(self.executer, param, ...)
        end
    end
end

function PSRedis:setup_pool(hosts)
    if not next(hosts) then
        log_err("[PSRedis][setup_pool] redis config err: hosts is empty")
        return
    end
    for ip, port in pairs(hosts) do
        local socket = Socket(self, ip, port)
        self.connections[1] = socket
        socket.task_queue = QueueFIFO()
        socket:set_id(1)
        break
    end
end

function PSRedis:on_socket_alive()
    for channel in pairs(self.subscribes) do
        self:subscribe(channel)
    end
    for channel in pairs(self.psubscribes) do
        self:psubscribes(channel)
    end
    event_mgr:notify_trigger("on_subscribe_alive")
end

function PSRedis:on_hour()
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
