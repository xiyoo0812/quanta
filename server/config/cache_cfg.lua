--cache_cfg.lua
--luacheck: ignore 631

--获取配置表
local config_mgr = quanta.get("config_mgr")
local cache = config_mgr:get_table("cache")

--导出配置内容
cache:upsert({
    id = 1,
    group = 'account',
    sheet = 'account',
    key = 'open_id',
    inertable = false,
    count = 100,
    time = 600,
    depth_min = 0,
    depth_max = 1,
})

cache:upsert({
    id = 2,
    group = 'lobby',
    sheet = 'player',
    key = 'player_id',
    inertable = false,
    count = 100,
    time = 600,
    depth_min = 0,
    depth_max = 1,
})

cache:upsert({
    id = 3,
    group = 'lobby',
    sheet = 'player_attr',
    key = 'player_id',
    inertable = false,
    count = 200,
    time = 600,
    depth_min = 1,
    depth_max = 2,
})

cache:update()
