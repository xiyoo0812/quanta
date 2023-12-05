--player_mgr.lua

local log_err       = logger.err
local log_debug     = logger.debug

local event_mgr     = quanta.get("event_mgr")
local update_mgr    = quanta.get("update_mgr")
local config_mgr    = quanta.get("config_mgr")
local protobuf_mgr  = quanta.get("protobuf_mgr")

local utility_db    = config_mgr:init_table("utility", "key")
local DAY_FLUSH     = utility_db:find_integer("value", "flush_day_hour")
local WEEK_FLUSH    = utility_db:find_integer("value", "flush_week_day")

local SERVER_UPHOLD = protobuf_mgr:error_code("KICK_SERVER_UPHOLD")

local Account       = import("lobby/player/account.lua")
local EntityMgr     = import("business/entity/entity_mgr.lua")

local PlayerMgr = singleton(EntityMgr)
local prop = property(PlayerMgr)
prop:reader("day_edition", 0)
prop:reader("week_edition", 0)
prop:reader("counter", nil)

function PlayerMgr:__init()
    update_mgr:attach_hour(self)
    update_mgr:attach_second30(self)
    self.counter = quanta.make_counter("player")
end

function PlayerMgr:on_hour(clock_ms, hour, time)
    if hour == DAY_FLUSH then
        --每周刷新
        local week_flush = (time.wday == WEEK_FLUSH)
        for _, player in self.entity_map:iterator() do
            player:day_update(week_flush)
        end
        event_mgr:notify_trigger("on_day_update", week_flush)
    end
end

function PlayerMgr:on_second30()
    event_mgr:notify_trigger("on_player_count", quanta.index, self.counter:get_info())
end

function PlayerMgr:kick_all()
    for player_id, player in self:iterator() do
        self:kick_out(player, player_id)
    end
end

function PlayerMgr:kick_out(player, player_id)
    player:send_gateway("rpc_kickout_client", SERVER_UPHOLD)
    event_mgr:notify_trigger("on_kickout_success", player_id, player)
end

--创建玩家
function PlayerMgr:load_player(account, player_id)
    local player = self:get_entity(player_id)
    if not player then
        local Player = import("lobby/player/player.lua")
        player = Player(player_id)
        --先加入
        self:add_entity(player_id, player)
        self.counter:count_increase()
    end
    if player:is_load_success() then
        return player
    end
    --初始化
    player:set_account(account)
    player:set_open_id(account.open_id)
    player:set_user_id(account.user_id)
    if player:setup() then
        return player
    end
end

--实体被销毁
function PlayerMgr:on_destory(player_id, player)
    self.counter:count_reduce()
    event_mgr:notify_trigger("on_logout_success", player_id, player)
end

--加载账号信息
function PlayerMgr:load_account(open_id, player_id)
    local account = Account(open_id)
    if not account:load() then
        log_err("[PlayerMgr][load_account] ({}-{})load account failed", open_id, player_id)
        return
    end
    return account
end

-- 广播消息
function PlayerMgr:broadcast_message(cmd_id, data)
    for _, player in self:iterator() do
        player:send(cmd_id, data)
    end
end

--群发信息
function PlayerMgr:group_message(players, cmd_id, data)
    log_debug("[PlayerMgr][group_message] players: {}, cmdid: {}", players, cmd_id)
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
