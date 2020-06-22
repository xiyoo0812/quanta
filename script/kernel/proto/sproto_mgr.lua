--sproto_mgr.lua
local lfs       = require('lfs')
local sproto    = require("driver.sproto")

local pairs     = pairs
local pcall     = pcall
local ldir      = lfs.dir
local open_file = io.open
local env_get   = environ.get
local ssub      = string.sub
local sfind     = string.find
local sformat   = string.format
local ssplit    = string_ext.split
local tunpack   = table.unpack
local log_err   = logger.err

local SprotoMgr = singleton()
local prop = property(SprotoMgr)
prop:accessor("proto_files", {})
prop:accessor("id_to_files", {})
prop:accessor("id_to_protos", {})
prop:accessor("allow_reload", false)
function SprotoMgr:__init()
    --初始化
    self:load_protos()
end

--加载pb文件
function SprotoMgr:load_protos()
    local proto_paths = ssplit(env_get("QUANTA_PROTO_PATH"), ";")
    for _, proto_path in pairs(proto_paths) do
        for file_name in ldir(proto_path) do
            local pos = sfind(file_name, ".sproto")
            if pos then
                local full_name = sformat("%s%s", proto_path, file_name)
                local file = open_file(full_name, "rb")
                local spb_data = file:read("*all")
                local pack_name = ssub(file_name, 1, pos - 1)
                self.proto_files[pack_name] = sproto.parse(spb_data)
                file:close()
            end
        end
        self:define_command(proto_path)
    end
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

function SprotoMgr:define_command(proto_dir)
    for file_name in ldir(proto_dir) do
        local pos = sfind(file_name, "%.lua")
        if pos then
            local res = import(sformat("%s%s", proto_dir, file_name))
            for id, name in pairs(res or {}) do
                if self.id_to_protos[id] then
                    log_err("[SprotoMgr][define_command] repeat id:%s, old:%s, new:%s", id, self.id_to_protos[id], name)
                end
                local pack_name, proto_name = tunpack(ssplit(name, "%."))
                self.id_to_files[id] = self.proto_files[pack_name]
                self.id_to_protos[id] = proto_name
            end
        end
    end
    self.allow_reload = true
end

-- 重新加载
function SprotoMgr:reload()
    if not self.allow_reload then
        return
    end
    -- register sproto文件
    self:load_protos()
end

quanta.sproto_mgr = SprotoMgr()

return SprotoMgr
