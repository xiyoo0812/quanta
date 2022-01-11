--graylog.lua
local ljson         = require("lcjson")

local log_err       = logger.err
local log_info      = logger.info
local json_encode   = ljson.encode
local sformat       = string.format
local tcopy         = table_ext.copy
local sid2sid       = service.id2sid
local sid2nick      = service.id2nick
local sid2name      = service.id2name
local sid2index     = service.id2index

local Socket        = import("driver/socket.lua")

local update_mgr    = quanta.get("update_mgr")

local GrayLog = class()
local prop = property(GrayLog)
prop:reader("ip", nil)          --mongo地址
prop:reader("sock", nil)        --网络连接对象
prop:reader("port", 27017)      --mongo端口
prop:reader("port", 27017)      --mongo端口

function GrayLog:__init(ip, port)
    self.ip = ip
    self.port = port
    --attach_second
    self.sock = Socket(self)
    update_mgr:attach_second(self)
end

function GrayLog:close()
    if self.sock then
        self.sock:close()
    end
end

function GrayLog:on_second()
    if not self.sock:is_alive() then
        if not self.sock:connect(self.ip, self.port) then
            log_err("[GrayLog][on_second] connect db(%s:%s:%s) failed!", self.ip, self.port, self.name)
            return
        end
        log_info("[GrayLog][on_second] connect db(%s:%s:%s) success!", self.ip, self.port, self.name)
    end
end

function GrayLog:write(host, quanta_id, message, level, debuf_info, optional)
    if not self.sock:is_alive() then
        return
    end
    local gelf = {
        version = "1.1",
        host = host,
        level = level,
        timestamp = quanta.now,
        short_message = message,
        file = debuf_info.short_src,
        line = debuf_info.linedefined,
        _node_id = quanta_id,
        _name = sid2name(quanta_id),
        _nick = sid2nick(quanta_id),
        _index = sid2index(quanta_id),
        _service = sid2sid(quanta_id)
    }
    if optional then
        tcopy(optional, gelf)
    end
    self.sock:send(sformat("%s\n", json_encode(gelf)))
end
