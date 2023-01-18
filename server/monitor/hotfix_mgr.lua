--monitor_mgr.lua
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
    local temp_file = iopen(temp_name, "w")
    temp_file:write(content)
    temp_file:flush()
    temp_file:close()
    -- 加密热更文件
    local parent_path = lpardir(lcurdir())
    local luac = lappend(lcurdir(), "luac")
    local output_path = lappend(parent_path, path)
    oexec(sformat("%s -o %s %s", luac, output_path, temp_name))
    --删除临时文件
    lremove(temp_path, true)
end

--获取配置并保存
function HotfixMgr:update_config(data_id, group, path)
    local content = nacos:get_config(data_id, group);
    if not content then
        log_warn("[HotfixMgr][update_config] update script:%s failed!", path)
        return
    end
    self:encrypt(path, content)
    log_debug("[HotfixMgr][update_config] update script: %s success!", path)
end

--热更
function HotfixMgr:hotfix_callback(group, md5, cvalue)
    --加载字典文件
    local dic_func, err = load(cvalue)
    if not dic_func then
        log_warn("[HotfixMgr][hotfix_callback] load dictionary failed: %s !", err)
        return
    end
    --更新版本配置
    self:update_config("server-hotfix-version.lua", group, "server/hotfix/version.lua")
    self:update_config("server-hotfix-dictionary.lua", group, "server/hotfix/dictionary.lua")
    --比对更新文件
    local dictionary = dic_func()
    for data_id, info in pairs(dictionary) do
        local old_info = self.dictionary[data_id]
        if not old_info or info.md5 ~= old_info.md5 then
            self:update_config(data_id, group, info.path)
        end
    end
    self.config.md5 = md5
    self.dictionary = dictionary
    --通知其他服务热更新
    monitor_mgr:broadcast_all("rpc_service_hotfix")
end

quanta.hotfix_mgr = HotfixMgr()

return HotfixMgr
