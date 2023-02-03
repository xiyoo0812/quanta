--player.lua
local log_warn      = logger.warn
local log_info      = logger.info
local qedition      = quanta.edition

local online        = quanta.get("online")
local login_dao     = quanta.get("login_dao")
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
local EventSet      = import("business/event/event_set.lua")

local Player = class(Entity, EventSet)

local prop = property(Player)
prop:reader("user_id")              --user_id
prop:reader("open_id")              --open_id
prop:reader("passkey", {})          --passkey
prop:reader("status", ONL_LOADING)
prop:reader("create_time", 0)       --create_time
prop:reader("online_time", 0)       --online_time
prop:accessor("gateway", nil)       --gateway
prop:accessor("login_time", 0)      --login_time
prop:accessor("upgrade_time", 0)    --upgrade_time

function Player:__init(id)
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

--load
function Player:load(conf)
    self:init_attrset(attr_db)
    self.active_time = quanta.now_ms
    local ok, data = login_dao:load_player(self.id)
    if ok then
        self.name = data.name
        self.user_id = data.user_id
        self.open_id = data.open_id
        self.login_time = data.login_time
        self.create_time = data.create_time
        self.online_time = data.online_time
        self.upgrade_time = data.upgrade_time
        self:set_gender(data.gender)
        self:set_custom(data.custom)
        self:set_relayable(true)
    end
    return ok
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

--update_time
function Player:update_time(time_key, time)
    self[time_key] = time
    login_dao:update_time(self.id, time_key, time)
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
    self.load_success = true
    self.status = ONL_INLINE
    self.active_time = quanta.now_ms
    self:set_version(self:build_version())
    self:add_passkey("lobby", quanta.id)
    self:update_time("login_time", quanta.now)
    log_info("[Player][online] player(%s) is online!", self.id)
    return true
end

--掉线
function Player:offline()
    self.gateway = nil
    self.status = ONL_OFFLINE
    self.active_time = quanta.now_ms
    --invoke
    self:invoke("_offline")
    log_warn("[Player][offline] player(%s) is offline!", self.id)
end

function Player:relive(gateway)
    self.gateway = gateway
    self.status = ONL_INLINE
    self.active_time = quanta.now_ms
    --invoke
    self:invoke("_relive")
    log_warn("[Player][relive] player(%s) is relive!", self.id)
end

--unload
function Player:unload()
    online:logout_player(self.id)
    login_dao:clear_account_lobby_status(self.user_id, 0)
    --计算在线时间
    local online_time = self.online_time + quanta.now - self.login_time
    self:update_time("online_time", online_time)
    return true
end

--heartbeat
function Player:heartbeat()
    self.active_time = quanta.now_ms
    --invoke
    self:invoke("_heartbeat")
end

return Player
