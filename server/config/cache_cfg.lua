--cache_cfg.lua
--luacheck: ignore 631

--获取配置表
local config_mgr = quanta.get("config_mgr")
local cache = config_mgr:get_table("cache")

--导出配置内容
cache:upsert({
    db_id = 1,
    group = 'account',
    coll_name = 'account',
    primary_key = 'open_id',
    expire_time = 600,
    flush_time = 1800,
    store_time = 10,
})

cache:upsert({
    db_id = 1,
    group = 'player',
    coll_name = 'player',
    primary_key = 'role_id',
    expire_time = 600,
    flush_time = 1800,
    store_time = 10,
})

cache:upsert({
    db_id = 1,
    group = 'player',
    coll_name = 'player_attr',
    primary_key = 'role_id',
    expire_time = 600,
    flush_time = 1800,
    store_time = 10,
})

cache:upsert({
    db_id = 1,
    group = 'player',
    coll_name = 'player_item',
    primary_key = 'role_id',
    expire_time = 600,
    flush_time = 1800,
    store_time = 10,
})

cache:upsert({
    db_id = 1,
    group = 'player',
    coll_name = 'player_store',
    primary_key = 'role_id',
    expire_time = 600,
    flush_time = 1800,
    store_time = 10,
})

--general md5 version
cache:set_version('8e4ad0f277b5f2785ac9dca096181972')