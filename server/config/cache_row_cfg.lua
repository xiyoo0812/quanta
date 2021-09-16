--cache_row_cfg.lua
--luacheck: ignore 631

--获取配置表
local config_mgr = quanta.get("config_mgr")
local cache_row = config_mgr:get_table("cache_row")

--导出版本号
cache_row:set_version(10000)

--导出配置内容
cache_row:upsert({
    cache_name = 'account',
    cache_table = 'account',
    cache_key = 'open_id',
})

cache_row:upsert({
    cache_name = 'career_image',
    cache_table = 'career_image',
    cache_key = 'player_id',
})

cache_row:upsert({
    cache_name = 'player',
    cache_table = 'player_role_info',
    cache_key = 'player_id',
})

cache_row:upsert({
    cache_name = 'player',
    cache_table = 'player_role_skin',
    cache_key = 'player_id',
})

cache_row:upsert({
    cache_name = 'player',
    cache_table = 'player_setting',
    cache_key = 'player_id',
})

cache_row:upsert({
    cache_name = 'player',
    cache_table = 'player_bag',
    cache_key = 'player_id',
})

cache_row:upsert({
    cache_name = 'player',
    cache_table = 'player_attribute',
    cache_key = 'player_id',
})

cache_row:upsert({
    cache_name = 'player',
    cache_table = 'player_reward',
    cache_key = 'player_id',
})

cache_row:upsert({
    cache_name = 'player',
    cache_table = 'player_vcard',
    cache_key = 'player_id',
})

cache_row:upsert({
    cache_name = 'player',
    cache_table = 'player_prepare',
    cache_key = 'player_id',
})

cache_row:upsert({
    cache_name = 'player',
    cache_table = 'player_career',
    cache_key = 'player_id',
})

cache_row:upsert({
    cache_name = 'player',
    cache_table = 'player_buff',
    cache_key = 'player_id',
})

cache_row:upsert({
    cache_name = 'player',
    cache_table = 'player_achieve',
    cache_key = 'player_id',
})

cache_row:upsert({
    cache_name = 'player',
    cache_table = 'player_standings',
    cache_key = 'player_id',
})

cache_row:upsert({
    cache_name = 'player',
    cache_table = 'player_battlepass',
    cache_key = 'player_id',
})
