--sproto_mgr.lua
local sproto_mgr = require("driver.sproto")

local pairs         = pairs
local pcall         = pcall
local ldir          = lfs.dir
local open_file     = io.open
local sfind         = string.find
local tunpack       = table.unpack
local log_err       = logger.err
local ssplit        = quanta_extend.split

local SprotoMgr = singleton()
function SprotoMgr:__init()
    self.proto_files = {}
    self.id_to_files = {}
    self.id_to_protos = {}
    self.open_reload_pb = false
end

--加载pb文件
function SprotoMgr:setup(spb_files)
    self.proto_files = {}
    for _, filename in ipairs(spb_files) do
        local file = open_file("proto/"..file_name..".sproto", "rb")
        if file then
            local spb_data = file:read("*all")
            self.proto_files[filename] = sproto.parse(spb_data)
            file:close()
        end
    end
    self:define_command()
end

function SprotoMgr:encode(cmd_id, data)
    local parser = self.id_to_files[cmd_id]
    local proto_name = self.id_to_protos[cmd_id]
    if not parser or not proto_name then
        log_err("[SprotoMgr][encode] find sproto name failed! cmd_id:%s", cmd_id)
        return nil
    end
    local ok, pb_str = pcall(parser.encode, parser, proto_name, data or {})
    if ok then
        return pb_str
    end
end

function SprotoMgr:decode(cmd_id, pb_str)
    local parser = self.id_to_files[cmd_id]
    local proto_name = self.id_to_protos[cmd_id]
    if not parser or not proto_name then
        log_err("[SprotoMgr][decode] find sproto name failed! cmd_id:%s", cmd_id)
        return nil
    end
    local ok, pb_data = pcall(parser.decode, parser, proto_name, pb_str)
    if ok then
        return pb_data
    end
end

function SprotoMgr:define_command()
    for file_name in ldir("./proto/") do
        local pos = sfind(file_name, "%.lua")
        if pos then
            import("../proto/"..file_name..".lua")
            for id, name in pairs(quanta[file_name]) do
                if self.id_to_protos[id] then
                    log_err("[SprotoMgr][define_command] repeat id:%s, old:%s, new:%s", id, self.id_to_protos[id], name)
                end
                local pack_name, proto_name = tunpack(ssplit(name, "."))
                self.id_to_files[id] = pack_name
                self.id_to_protos[id] = proto_name
            end
        end
    end
    self.open_reload_pb = true
end

-- 重新加载
function SprotoMgr:reload()
    if not self.open_reload_pb then
        return
    end
    -- register sproto文件
    for filename in pairs(self.proto_files) do
        local file = open_file("proto/"..file_name..".sproto", "rb")
        if file then
            local spb_data = file:read("*all")
            self.proto_files[filename] = sproto.parse(spb_data)
            file:close()
        end
    end
    -- 映射id与pb消息名
    self:define_command()
end

quanta.sproto_mgr = SprotoMgr()

return SprotoMgr
