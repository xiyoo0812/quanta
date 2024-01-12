-- cache_gm.lua
import("agent/gm_agent.lua")

local log_info      = logger.info
local log_err       = logger.err
local sformat       = string.format
local qfailed       = quanta.failed
local unserialize   = luakit.unserialize

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
            args = "player_id|integer coll_name|string datas|string",
            example = "update_cache 1130045456 player {xxx=xxx}",
            tip = "示例中，1130045456为玩家ID, player为表名 datas为新数据"
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
            args = "player_id|integer",
            example = "signed 1001021787",
            tip = "示例中, 1001021787为角色ID"
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
function CacheGM:signed(role_id)
    --查询open_id
    local p_code, player_doc = cache_mgr:load_document("player", role_id)
    if qfailed(p_code) then
        log_err("[CacheGM][signed] load_document failed! role_id={}", role_id)
        return "failed"
    end

    local open_id = player_doc:get_wholes().open_id
    if not open_id then
        return "failed. cant find data"
    end
    log_info("[CacheGM][signed] unroll role_id:{} open_id:{}", role_id, open_id)
    local code, doc = cache_mgr:load_document("account", open_id)
    if qfailed(code) then
        log_err("[CacheGM][signed] load_document failed! open_id={}", open_id)
        return "failed"
    end
    local wholes = doc:get_wholes()
    wholes.roles = {}
    doc:update_wholes(wholes)
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
    log_info("[CacheGM][copy_cache] to_player_id={}, player_id={}, coll_name={}", to_player_id, player_id, coll_name)
    local coll_cfg = cache_db:find_one(coll_name)
    if not coll_cfg then
        return sformat("{} not found cache", coll_name)
    end
    if not coll_cfg.copyable then
        return sformat("{} cant copy", coll_name)
    end

    local ok = cache_mgr:rpc_cache_copy(to_player_id, player_id,  coll_name)
    if not ok then
        return "failed"
    end
    return "success"
end

--删除缓存
function CacheGM:del_cache(player_id, coll_name)
    log_info("[CacheGM][del_cache] player_id={} coll_name={}", player_id, coll_name)
    -- 通知服务
    local ok = cache_mgr:rpc_cache_delete(player_id, coll_name)
    if not ok then
        return "cache not find"
    end
    return "success"
end

--更新缓存
function CacheGM:update_cache(player_id, coll_name, datas)
    log_info("[CacheGM][update_cache] player_id:{} coll_name={} datas:{}", player_id, coll_name, datas)
    local pok, wdatas = pcall(unserialize, datas)
    if not pok or not wdatas then
        return sformat("parse failed. field_data:{}", wdatas)
    end
    local code, doc = cache_mgr:load_document(coll_name, player_id)
    if qfailed(code) then
        log_err("[CacheGM][update_cache] load_document failed! player_id={}", player_id)
        return "failed"
    end
    doc:update_wholes(wdatas)
    return "success"
end

--查询缓存
function CacheGM:query_cache(player_id, coll_name)
    log_info("[CacheGM][query_cache] player_id={} coll_name={}", player_id, coll_name)
    -- 通知服务
    local ok, doc = cache_mgr:load_document(coll_name, player_id)
    if not ok or not doc then
        return "cache not find"
    end
    log_info("[CacheGM][query_cache] player_id={} coll_name={} datas:{}", player_id, coll_name, doc:get_wholes())
    return doc:get_wholes()
end

-- export
quanta.cache_gm = CacheGM()

return CacheGM
