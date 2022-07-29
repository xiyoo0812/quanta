--player_attr_cfg.lua
--luacheck: ignore 631

--获取配置表
local config_mgr = quanta.get("config_mgr")
local player_attr = config_mgr:get_table("player_attr")

--导出配置内容
player_attr:upsert({
    key = 'ATTR_HP',
    range = 16,
    save = true,
    limit = 'hp_max',
})

player_attr:upsert({
    key = 'ATTR_MP',
    range = 1,
    save = true,
    limit = 'mp_max',
})

player_attr:upsert({
    key = 'ATTR_STANIMA',
    range = 1,
    save = true,
    limit = 'stanima_max',
})

player_attr:upsert({
    key = 'ATTR_EXP',
    range = 1,
    save = true,
    limit = 'exp_max',
})

player_attr:upsert({
    key = 'ATTR_HP_MAX',
    range = 16,
    save = false,
})

player_attr:upsert({
    key = 'ATTR_MP_MAX',
    range = 1,
    save = false,
})

player_attr:upsert({
    key = 'ATTR_STANIMA_MAX',
    range = 1,
    save = false,
})

player_attr:upsert({
    key = 'ATTR_EXP_MAX',
    range = 1,
    save = false,
})

player_attr:upsert({
    key = 'ATTR_LEVEL',
    range = 16,
    save = true,
})

player_attr:upsert({
    key = 'ATTR_COIN',
    range = 1,
    save = true,
})

player_attr:upsert({
    key = 'ATTR_JEWEL',
    range = 1,
    save = true,
})

player_attr:upsert({
    key = 'ATTR_DIAMOND',
    range = 1,
    save = true,
})

player_attr:upsert({
    key = 'ATTR_LUCKY',
    range = 1,
    save = true,
})

player_attr:upsert({
    key = 'ATTR_ATTACK',
    range = 1,
    save = false,
})

player_attr:upsert({
    key = 'ATTR_DEFENCE',
    range = 1,
    save = false,
})

player_attr:upsert({
    key = 'ATTR_CRITICAL_RATE',
    range = 1,
    save = false,
})

player_attr:upsert({
    key = 'ATTR_CRITICAL_HURT',
    range = 1,
    save = false,
})

player_attr:upsert({
    key = 'ATTR_HEAD',
    range = 16,
    save = true,
})

player_attr:upsert({
    key = 'ATTR_FACE',
    range = 16,
    save = true,
})

player_attr:upsert({
    key = 'ATTR_CLOTH',
    range = 16,
    save = true,
})

player_attr:upsert({
    key = 'ATTR_TROUSERS',
    range = 16,
    save = true,
})

player_attr:upsert({
    key = 'ATTR_SHOES',
    range = 16,
    save = true,
})

player_attr:upsert({
    key = 'ATTR_WEAPON',
    range = 16,
    save = true,
})

player_attr:upsert({
    key = 'ATTR_NECK',
    range = 0,
    save = false,
})

player_attr:upsert({
    key = 'ATTR_RING',
    range = 0,
    save = false,
})

player_attr:upsert({
    key = 'ATTR_SHUT_KEY1',
    range = 1,
    save = true,
})

player_attr:upsert({
    key = 'ATTR_SHUT_KEY2',
    range = 1,
    save = true,
})

player_attr:upsert({
    key = 'ATTR_SHUT_KEY3',
    range = 1,
    save = true,
})

player_attr:upsert({
    key = 'ATTR_SHUT_KEY4',
    range = 1,
    save = true,
})

player_attr:upsert({
    key = 'ATTR_SHUT_KEY5',
    range = 1,
    save = true,
})

player_attr:upsert({
    key = 'ATTR_SHUT_KEY6',
    range = 1,
    save = true,
})

player_attr:upsert({
    key = 'ATTR_SHUT_KEY7',
    range = 1,
    save = true,
})

player_attr:upsert({
    key = 'ATTR_SHUT_KEY8',
    range = 1,
    save = true,
})

player_attr:upsert({
    key = 'ATTR_MAP_ID',
    range = 0,
    save = true,
})

player_attr:upsert({
    key = 'ATTR_POS_X',
    range = 0,
    save = true,
})

player_attr:upsert({
    key = 'ATTR_POS_Y',
    range = 0,
    save = true,
})

player_attr:upsert({
    key = 'ATTR_POS_Z',
    range = 0,
    save = true,
})

--general md5 version
player_attr:set_version('74d4b6e6df03d957747d18af63012fa4')