--player_mgr.lua

local log_debug     = logger.debug

local event_mgr     = quanta.get("event_mgr")
local update_mgr    = quanta.get("update_mgr")
local config_mgr    = quanta.get("config_mgr")

local utility_db    = config_mgr:init_table("utility", "key")
local DAY_FLUSH     = utility_db:find_integer("value", "flush_day_hour")
local WEEK_FLUSH    = utility_db:find_integer("value", "flush_week_day")

local EntityMgr     = import("business/entity/entity_mgr.lua")

local PlayerMgr = singleton(EntityMgr)
local prop = property(PlayerMgr)
prop:reader("day_edition", 0)
prop:reader("week_edition", 0)
prop:reader("min_count", 0)
prop:reader("max_count", 0)

function PlayerMgr:__init()
    update_mgr:attach_hour(self)
    update_mgr:attach_minute(self)
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

function PlayerMgr:on_minute()
    local cur_count = self:size()
    event_mgr:notify_trigger("on_player_count", quanta.index, cur_count, self.max_count, self.min_count)
    self.min_count = cur_count
    self.max_count = cur_count
end

--创建玩家
function PlayerMgr:load_player(player_id)
    local player = self:get_entity(player_id)
    if not player then
        local Player = import("lobby/player/player.lua")
        player = Player(player_id)
        self:calc_player_max()
        if player:setup() then
            self:add_entity(player_id, player)
            return player
        end
    end
    return player
end

--实体被销毁
function PlayerMgr:on_destory(player, player_id)
    update_mgr:attach_event(player_id, "on_logout_success", player_id, player)
    self:calc_player_min()
end

--计算窗口内的最低在线人数
function PlayerMgr:calc_player_min()
    local cur_count = self:size()
    if self.min_count > cur_count then
        self.min_count = cur_count
    end
end

--计算窗口内的最高在线人数
function PlayerMgr:calc_player_max()
    local cur_count = self:size()
    if self.max_count < cur_count then
        self.max_count = cur_count
    end
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
