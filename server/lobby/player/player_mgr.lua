--player_mgr.lua

local log_debug     = logger.debug

local update_mgr    = quanta.get("update_mgr")
local config_mgr    = quanta.get("config_mgr")

local utility_db    = config_mgr:init_table("utility", "key")
local DAY_FLUSH     = utility_db:find_value("value", "flush_day_hour")
local WEEK_FLUSH    = utility_db:find_value("value", "flush_week_day")

local EntityMgr     = import("business/entity/entity_mgr.lua")

local PlayerMgr = singleton(EntityMgr)
local prop = property(PlayerMgr)
prop:reader("day_edition", 0)
prop:reader("week_edition", 0)

function PlayerMgr:__init()
    update_mgr:attach_hour(self)
end

function PlayerMgr:on_hour(hour, time)
    if hour == DAY_FLUSH then
        --每周刷新
        local week_flush = (time.wday == WEEK_FLUSH)
        for _, player in self.player_map:iterator() do
            player:day_update(week_flush)
        end
    end
end

--创建玩家
function PlayerMgr:load_player(player_id)
    local player = self:get_entity(player_id)
    if not player then
        local Player = import("lobby/player/player.lua")
        player = Player(player_id)
        if player:setup() then
            self:add_entity(player_id, player)
            return player
        end
    end
    return player
end

-- 广播消息
function PlayerMgr:broadcast_message(cmd_id, data)
    for _, player in self:iterator() do
        player:send(cmd_id, data)
    end
end

--群发信息
function PlayerMgr:group_message(players, cmd_id, data)
    log_debug("[PlayerMgr][group_message] players: %s, cmdid: %s", players, cmd_id)
    for _, player_id in pairs(players) do
        local player = self:get_entity(player_id)
        if player then
            player:send(cmd_id, data)
        end
    end
end

-- export
quanta.player_mgr = PlayerMgr()

return PlayerMgr
