--monitor_mgr.lua
local lcodec        = require("lcodec")
local lstdfs        = require("lstdfs")

local iopen         = io.open
local oexec         = os.execute
local log_warn      = logger.warn
local log_debug     = logger.debug
local sformat       = string.format
local lmkdir        = lstdfs.mkdir
local lappend       = lstdfs.append
local lremove       = lstdfs.remove
local ltemp_dir     = lstdfs.temp_dir
local lpardir       = lstdfs.parent_path
local lcurdir       = lstdfs.current_path
local serialize     = lcodec.serialize

local nacos         = quanta.get("nacos")
local thread_mgr    = quanta.get("thread_mgr")
local monitor_mgr   = quanta.get("monitor_mgr")

local HotfixMgr = singleton()
local prop = property(HotfixMgr)
prop:reader("config",  {})
prop:reader("dictionary", {})

function HotfixMgr:__init()
    self:init_nacos()
end

--初始化nacos
function HotfixMgr:init_nacos()
    local hotfixable = environ.status("QUANTA_NACOS_HOTFIX")
    if hotfixable then
        thread_mgr:fork(function()
            self.config = import("hotfix/version.lua")
            self.dictionary = import("hotfix/dictionary.lua")
            log_debug("[HotfixMgr][init_nacos] versions:%s", self.config)
            --回调函数
            local config_changed = function(data_id, group, md5, cvalue)
                log_debug("[HotfixMgr][config_changed]: dataid:%s md5:%s", data_id, md5)
                self:hotfix_callback(group, md5, cvalue)
            end
            nacos:listen_config(self.config.data_id, self.config.group, self.config.md5, config_changed)
        end)
    end
end

--加密并保存
function HotfixMgr:encrypt(path, content)
    --构建临时路径
    local temp_path
    if quanta.platform == "windows" then
        temp_path = ltemp_dir()
    else
        temp_path = "/tmp/mtae_server"
    end
    local temp_name = lappend(temp_path, path)
    local file_path = lpardir(temp_name)
    lmkdir(file_path)
    -- 写入热更文件
    local temp_file<close> = iopen(temp_path, "w")
    temp_file:write(content)
    -- 加密热更文件
    local parent_path = lpardir(lcurdir())
    local luac = lappend(lcurdir(), "luac")
    local output_path = lappend(parent_path, path)
    oexec(sformat("%s -o %s %s", luac, output_path, temp_path))
    --删除临时文件
    lremove(temp_path, true)
end

--获取配置并保存
function HotfixMgr:update_config(data_id, group, path)
    local content = nacos:get_config(data_id, group);
    if not content then
        log_warn("[HotfixMgr][update_config] update data_id:%s failed!", data_id)
        return
    end
    self:encrypt(path, content)
end

--热更
function HotfixMgr:hotfix_callback(group, md5, cvalue)
    self.config.md5 = md5
    local parent_path = lpardir(lcurdir())
    --保存热更配置
    local version_name = lappend(parent_path, "server/hotfix/version.lua")
    local fversion<close> = iopen(version_name, "w")
    local content = sformat("-- version.lua\n\nreturn %s", serialize(self.config, true))
    fversion:write(content)
    --保存文件字典
    local dict_name = lappend(parent_path, "server/hotfix/dictionary.lua")
    local fdict<close> = iopen(dict_name, "w")
    fdict:write(cvalue)
    --加载文件字典
    local dictionary = import("hotfix/dictionary.lua")
    for data_id, info in pairs(dictionary) do
        local old_info = self.dictionary[data_id]
        if not old_info or info.md5 ~= old_info.md5 then
            self:update_config(data_id, group, info.path)
        end
    end
    self.dictionary = dictionary
    --通知其他服务热更新
    monitor_mgr:broadcast_all("rpc_service_hotfix")
end

quanta.hotfix_mgr = HotfixMgr()

return HotfixMgr
