--player.lua
local log_warn      = logger.warn
local log_info      = logger.info
local qedition      = quanta.edition
local makechan      = quanta.make_channel

local store_mgr     = quanta.get("store_mgr")
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
local SubComponent  = import("business/component/sub_component.lua")

local Player = class(Entity, MsgComponent, SubComponent)

local prop = property(Player)
prop:reader("status", 0)            --status
prop:reader("create_time", 0)       --create_time
prop:reader("routers", {})          --routers
prop:accessor("user_id", nil)       --user_id
prop:accessor("open_id", nil)       --open_id
prop:accessor("account", nil)       --account

local dprop = db_property(Player, "player", true)
dprop:store_value("nick", "")       --nick
dprop:store_value("facade", "")     --nick
dprop:store_value("upgrade_time", 0)--upgrade_time
dprop:store_value("energy_tick", 0)--下次能量恢复时间
function Player:__init(id)
end

function Player:on_db_player_load(data)
    if data.player_id then
        self.nick = data.nick
        self.facade = data.facade
        self.create_time = data.create_time
        self.upgrade_time = data.upgrade_time or 0
        self.energy_tick = data.energy_tick or quanta.now
        self.routers = data.routers or {}
        self:set_gender(data.gender)
        self:set_custom(data.facade)
        self:set_name(data.nick)
        self:set_relayable(true)
        return true
    end
    return false
end

-- 更新路由
function Player:update_router(name, id)
    self.routers[name] = id
end

function Player:find_router(name)
    return self.routers[name] or 0
end

--load
function Player:load(conf)
    self.status = ONL_LOADING
    self.active_time = quanta.now_ms
    self:init_attrset(attr_db, 1)
    local channel = makechan("load_player")
    channel:push(function()
        return store_mgr:load_group(self, self.id, "player")
    end)
    channel:push(function()
        return store_mgr:load_group(self, self.id, "lobby")
    end)
    self:invoke("_load", channel, self.id)
    local ok, code =  channel:execute()
    if not ok then
        log_warn("[Player][load] player({}) failed: {}!", self.id, code)
    end
    return ok
end

--修改玩家名字
function Player:update_name(name)
    self:set_name(name)
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
    return self:get_login_time() == 0
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
            log_warn("[Player][check] player({}) load too long, will be destory!", self.id)
            self:set_release(true)
            self.status = ONL_CLOSE
        end
        return false
    end
    if self.status == ONL_OFFLINE then
        --掉线清理
        if now_ms - self.active_time > OFFTIMEOUT then
            log_warn("[Player][check] player({}) offline too long, will be destory!", self.id)
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
    self.release = false
    self.status = ONL_INLINE
    self.active_time = quanta.now_ms
    self:set_version(self:build_version())
    --invoke
    self:invoke("_online")
    --load success
    self:set_login_time(quanta.now)
    self.load_success = true
    log_info("[Player][online] player({}) is online!", self.id)
end

--掉线
function Player:offline()
    self.status = ONL_OFFLINE
    self.active_time = quanta.now_ms
    --invoke
    self:invoke("_offline")
    log_warn("[Player][offline] player({}) is offline!", self.id)
end

function Player:relive()
    self.release = false
    self.status = ONL_INLINE
    self.active_time = quanta.now_ms
    --invoke
    self:invoke("_relive")
    log_warn("[Player][relive] player({}) is relive!", self.id)
end

--unload
function Player:unload()
    self:invoke("_unload")
    self.account:save_lobby(0)
    --计算在线时间
    self:add_online_time(quanta.now - self:get_login_time())
    self:set_login_time(quanta.now)
    return true
end

--heartbeat
function Player:heartbeat()
    self.active_time = quanta.now_ms
    --invoke
    self:invoke("_heartbeat", quanta.now)
end

return Player
