--cache_cfg.lua
--source: cache.csv
--luacheck: ignore 631

--获取配置表
local config_mgr = quanta.get("config_mgr")
local cache = config_mgr:get_table("cache")

--导出配置内容
cache:upsert({
    copyable=false,
    count=100,
    group='account',
    id=1,
    inertable=false,
    key='open_id',
    sheet='account',
    time=600
})

cache:upsert({
    copyable=true,
    count=100,
    group='player',
    id=2,
    inertable=false,
    key='player_id',
    key2='nick',
    sheet='player',
    time=600
})

cache:upsert({
    copyable=true,
    count=200,
    group='lobby',
    id=3,
    inertable=false,
    key='player_id',
    sheet='player_attr',
    time=600
})

cache:update()
