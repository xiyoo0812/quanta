-- cache_gm.lua
import("agent/gm_agent.lua")

local log_info      = logger.info

local gm_agent      = quanta.get("gm_agent")
local cache_mgr     = quanta.get("cache_mgr")

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
        }
    }

    --注册GM
    gm_agent:insert_command(cmd_list)
    -- 初始化监听事件
    for _, cmd in ipairs(cmd_list) do
        gm_agent:add_listener(self, cmd.name)
    end
end

--查询缓存
function CacheGM:query_cache(player_id, coll_name)
    log_info("[CacheGM][query_cache] player_id=%s coll_name=%s", player_id, coll_name)
    -- 通知服务
    local ok, doc = cache_mgr:load_document(coll_name, player_id)
    if not ok or not doc then
        return "cache not find"
    end
    return doc:get_datas()
end

-- export
quanta.cache_gm = CacheGM()

return CacheGM
