-- cache_gm.lua
import("agent/gm_agent.lua")

local log_info      = logger.info
local log_err       = logger.err
local sformat       = string.format
local unserialize   = quanta.unserialize
local qfailed       = quanta.failed

local gm_agent      = quanta.get("gm_agent")
local cache_mgr     = quanta.get("cache_mgr")
local config_mgr    = quanta.get("config_mgr")
local cache_db      = config_mgr:init_table("cache", "sheet")

local HASHKEY       = quanta.enum("GMType", "HASHKEY")

local CacheGM = singleton()
function CacheGM:__init()
    self:register()
end

-- 注册
function CacheGM:register()
    local cmd_list = {
        {
            name = "query_cache",
            gm_type = HASHKEY,
            group = "数据",
            desc = "查询缓存数据",
            args = "player_id|integer coll_name|string",
            example = "query_cache 1130045456 player",
            tip = "示例中，1130045456为玩家ID, player为表名"
        },
        {
            name = "del_cache",
            gm_type = HASHKEY,
            group = "数据",
            desc = "删除缓存数据",
            args = "player_id|integer coll_name|string",
            example = "query_cache 1130045456 player",
            tip = "示例中，1130045456为玩家ID, player为表名"
        },
        {
            name = "update_cache",
            gm_type = HASHKEY,
            group = "数据",
            desc = "更新缓存数据",
            args = "player_id|integer coll_name|string field|string, field_data|string",
            example = "update_cache 1130045456 player nick nickxxx",
            tip = "示例中，1130045456为玩家ID, player为表名 filed为全路径field, field_data为对应value"
        },
        {
            name = "copy_cache",
            gm_type = HASHKEY,
            group = "数据",
            desc = "复制缓存数据",
            args = "to_player_id|integer player_id|integer coll_name|string",
            example = "copy_cache 1130045456 1130045457 player",
            tip = "示例中，1130045456为目标玩家ID,1130045457为原玩家ID player为表名"
        },
        {
            name = "one_key_copy",
            gm_type = HASHKEY,
            group = "数据",
            desc = "一键复制角色数据",
            args = "to_player_id|integer player_id|integer",
            example = "one_key_copy 1130045456 1130045457",
            tip = "示例中，1130045456为目标玩家ID,1130045457为原玩家ID"
        },
        {
            name = "signed",
            gm_type = HASHKEY,
            group = "数据",
            desc = "删除角色",
            args = "tplayer_id|integer",
            example = "signed 1130045456",
            tip = "示例中，1130045456为目标玩家ID"
        },

    }

    --注册GM
    gm_agent:insert_command(cmd_list)
    -- 初始化监听事件
    for _, cmd in ipairs(cmd_list) do
        gm_agent:add_listener(self, cmd.name)
    end
end

--删除角色
function CacheGM:signed(player_id)
    --加载open_id
    local code, doc = cache_mgr:load_document("player", player_id)
    if qfailed(code) then
        log_err("[CacheGM][signed] load_document failed! player_id=%s", player_id)
        return "failed"
    end
    local open_id = doc:get_datas().open_id
    --标记account中的roles信息
    local ok =  cache_mgr:rpc_cache_remove_field(open_id, "account", sformat("roles.%s", player_id))
    if not ok then
        return "failed"
    end

    cache_mgr:rpc_cache_signed(player_id, "player")
    cache_mgr:rpc_cache_delete(player_id, "player_mirror")
    return "success"
end

--一键复制
function CacheGM:one_key_copy(to_player_id, player_id)
    for _, conf in cache_db:iterator() do
        if conf.copyable then
            self:copy_cache( to_player_id, player_id, conf.sheet)
        end
    end
    return "success"
end

--复制缓存数据
function CacheGM:copy_cache(to_player_id, player_id, coll_name)
    log_info("[CacheGM][copy_cache] to_player_id=%s, player_id=%s, coll_name=%s", to_player_id, player_id, coll_name)
    local coll_cfg = cache_db:find_one(coll_name)
    if not coll_cfg then
        return sformat("%s not found cache", coll_name)
    end
    if not coll_cfg.copyable then
        return sformat("%s cant copy", coll_name)
    end

    local ok = cache_mgr:rpc_cache_copy(to_player_id, player_id,  coll_name)
    if not ok then
        return "failed"
    end
    return "success"
end

--删除缓存
function CacheGM:del_cache(player_id, coll_name)
    log_info("[CacheGM][del_cache] player_id=%s coll_name=%s", player_id, coll_name)
    -- 通知服务
    local ok = cache_mgr:rpc_cache_delete(player_id, coll_name)
    if not ok then
        return "cache not find"
    end
    return "success"
end

--更新缓存
function CacheGM:update_cache(player_id, coll_name, field, field_data)
    log_info("[CacheGM][update_cache] player_id:%s coll_name=%s field:%s, field_data:%s", player_id, coll_name, field, field_data)

    local pok, datas = pcall(unserialize, field_data)
    if not pok or not datas then
        return sformat("parse failed. field_data:%s", field_data)
    end

    local ok = cache_mgr:rpc_cache_update_field(player_id, coll_name, field, datas)
    if not ok then
        return sformat("failed code:%s", ok)
    end
    return "success"
end

--查询缓存
function CacheGM:query_cache(player_id, coll_name)
    log_info("[CacheGM][query_cache] player_id=%s coll_name=%s", player_id, coll_name)
    -- 通知服务
    local ok, doc = cache_mgr:load_document(coll_name, player_id)
    if not ok or not doc then
        return "cache not find"
    end
    log_info("[CacheGM][query_cache] player_id=%s coll_name=%s datas:%s", player_id, coll_name, doc:get_datas())
    return doc:get_datas()
end

-- export
quanta.cache_gm = CacheGM()

return CacheGM
