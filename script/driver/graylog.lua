--graylog.lua
import("network/http_client.lua")
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
local http_client   = quanta.get("http_client")

local GrayLog = class()
local prop = property(GrayLog)
prop:reader("ip", nil)          --地址
prop:reader("sock", nil)        --网络连接对象
prop:reader("port", 12021)      --端口
prop:reader("addr", nil)        --http addr

function GrayLog:__init()
end

function GrayLog:tcp(ip, port)
    self.ip = ip
    self.port = port
    --attach_second
    self.sock = Socket(self)
    update_mgr:attach_second(self)
end

function GrayLog:http(ip, port)
    self.addr = sformat("http://%s:%s/gelf", ip, port)
    log_info("[GrayLog][http] setup (%s) success!", self.addr)
end

function GrayLog:close()
    if self.sock then
        self.sock:close()
    end
end

function GrayLog:on_second()
    if not self.sock:is_alive() then
        if not self.sock:connect(self.ip, self.port) then
            log_err("[GrayLog][on_second] connect (%s:%s) failed!", self.ip, self.port, self.name)
            return
        end
        log_info("[GrayLog][on_second] connect (%s:%s) success!", self.ip, self.port, self.name)
    end
end

function GrayLog:build(host, quanta_id, message, level, debug_info, optional)
    local gelf = {
        version = "1.1",
        host = host,
        level = level,
        timestamp = quanta.now,
        short_message = message,
        _node_id = quanta_id,
        _name = sid2name(quanta_id),
        _nick = sid2nick(quanta_id),
        _index = sid2index(quanta_id),
        _service = sid2sid(quanta_id)
    }
    if debug_info then
        gelf.file = debug_info.short_src
        gelf.line = debug_info.linedefined
    end
    if optional then
        tcopy(optional, gelf)
    end
    return gelf
end

function GrayLog:send_tcp(host, quanta_id, message, level, debug_info, optional)
    if not self.sock:is_alive() then
        return
    end
    local gelf = self:build(host, quanta_id, message, level, debug_info, optional)
    self.sock:send(sformat("%s\0", json_encode(gelf)))
end

function GrayLog:send_http(host, quanta_id, message, level, debug_info, optional)
    local gelf = self:build(host, quanta_id, message, level, debug_info, optional)
    local ok, status, res = http_client:call_post(self.addr, gelf)
    if not ok then
        log_err("[GrayLog][send_http] failed! code: %s, err: %s", status, res)
    end
end

return GrayLog
