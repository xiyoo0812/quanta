--player.lua
local log_warn      = logger.warn
local log_info      = logger.info
local qedition      = quanta.edition

local online        = quanta.get("online")
local game_dao      = quanta.get("game_dao")
local config_mgr    = quanta.get("config_mgr")

local attr_db       = config_mgr:init_table("player_attr", "key")
local utility_db    = config_mgr:init_table("utility", "key")

local OFFTIMEOUT    = quanta.enum("NetwkTime", "OFFLINE_TIMEOUT")
local SECOND_5_MS   = quanta.enum("PeriodTime", "SECOND_5_MS")

local ONL_LOADING   = quanta.enum("OnlineStatus", "LOADING")
local ONL_INLINE    = quanta.enum("OnlineStatus", "INLINE")
local ONL_OFFLINE   = quanta.enum("OnlineStatus", "OFFLINE")
local ONL_CLOSE     = quanta.enum("OnlineStatus", "CLOSE")

local DAY_FLUSH_S   = utility_db:find_integer("value", "flush_day_hour") * 3600

local Entity        = import("business/entity/entity.lua")
local MsgComponent  = import("business/component/msg_component.lua")

local Player = class(Entity, MsgComponent)

local prop = property(Player)
prop:reader("user_id")              --user_id
prop:reader("passkey", {})          --passkey
prop:reader("status", 0)            --status
prop:reader("create_time", 0)       --create_time
prop:accessor("open_id", nil)       --open_id
prop:accessor("gateway", nil)       --gateway
prop:accessor("account", nil)       --account

local dprop = db_property(Player, "player", true)
dprop:store_value("nick", "")       --nick
dprop:store_value("facade", "")     --nick
dprop:store_value("login_time", 0)  --login_time
dprop:store_value("upgrade_time", 0)--upgrade_time

function Player:__init(id)
end

function Player:on_db_player_load(data)
    if data.player_id then
        self.nick = data.nick
        self.facade = data.facade
        self.user_id = data.user_id
        self.login_time = data.login_time
        self.create_time = data.create_time
        self.upgrade_time = data.upgrade_time or 0
        self:set_gender(data.gender)
        self:set_custom(data.facade)
        self:set_name(data.nick)
        self:set_relayable(true)
        self.active_time = quanta.now_ms
        return true
    end
    return false
end

--load
function Player:load(conf)
    self.status = ONL_LOADING
    self.active_time = quanta.now_ms
    self:init_attrset(attr_db, 1)
    return game_dao:load_group(self, "lobby", self.id)
end

--修改玩家名字
function Player:update_name(name)
    self:save_name(name)
    self:save_nick(name)
    self.account:update_nick(self.id, name)
end

--修改玩家外观
function Player:update_custom(custom)
    self:save_facade(custom)
    self.account:update_custom(self.id, custom)
end

--是否新玩家
function Player:is_newbee()
    return self.login_time == 0
end

--添加钥匙
function Player:add_passkey(key, id)
    self.passkey[key] = id
end

--添加钥匙
function Player:find_passkey(key)
    return self.passkey[key]
end

--day_update
function Player:day_update(week_flush)
    self:invoke("_day_update", week_flush)
    self:set_version(self:build_version())
end

function Player:build_version()
    return qedition("day", quanta.now, DAY_FLUSH_S)
end

--update
function Player:check(now)
    if self.status == ONL_CLOSE then
        return false
    end
    local now_ms = quanta.now_ms
    if self.status == ONL_LOADING then
        --加载失败
        if now_ms - self.active_time > SECOND_5_MS then
            log_warn("[Player][check] player(%s) load too long, will be destory!", self.id)
            self:set_release(true)
            self.status = ONL_CLOSE
        end
        return false
    end
    if self.status == ONL_OFFLINE then
        --掉线清理
        if now_ms - self.active_time > OFFTIMEOUT then
            log_warn("[Player][check] player(%s) offline too long, will be destory!", self.id)
            self:set_release(true)
            self.status = ONL_CLOSE
        end
        return false
    end
    return true
end

--数据同步
function Player:sync_data()
    self:invoke("_sync_data")
end

--online
function Player:online()
    --invoke
    local call_ok = self:collect("_online")
    if not call_ok then
        log_warn("[Player][online] Player %s online faild!", self.id)
        return call_ok
    end
    self.release = false
    self.status = ONL_INLINE
    self.active_time = quanta.now_ms
    self:set_version(self:build_version())
    self:add_passkey("lobby", quanta.id)
    self:save_login_time(quanta.now)
    self.load_success = true
    log_info("[Player][online] player(%s) is online!", self.id)
    return true
end

--掉线
function Player:offline()
    self.gateway = nil
    self.status = ONL_OFFLINE
    self.active_time = quanta.now_ms
    --计算在线时间
    self:add_online_time(quanta.now - self.login_time)
    --invoke
    self:invoke("_offline")
    log_warn("[Player][offline] player(%s) is offline!", self.id)
end

function Player:relive(gateway)
    self.release = false
    self.gateway = gateway
    self.status = ONL_INLINE
    self.active_time = quanta.now_ms
    --invoke
    self:invoke("_relive")
    log_warn("[Player][relive] player(%s) is relive!", self.id)
end

--unload
function Player:unload()
    self:invoke("_unload")
    self.account:save_lobby(0)
    online:logout_player(self.id)
    return true
end

--heartbeat
function Player:heartbeat()
    self.active_time = quanta.now_ms
    --invoke
    self:invoke("_heartbeat", quanta.now)
end

return Player
