--player_attr_cfg.lua
--luacheck: ignore 631

--获取配置表
local config_mgr = quanta.get("config_mgr")
local player_attr = config_mgr:get_table("player_attr")

--导出配置内容
player_attr:upsert({
    key = 'ATTR_HP',
    nick = 'hp',
    range = 16,
    save = {0},
})

player_attr:upsert({
    key = 'ATTR_MP',
    nick = 'mp',
    range = 0,
    save = {0},
})

player_attr:upsert({
    key = 'ATTR_POWER',
    nick = 'power',
    range = 1,
    save = {0},
})

player_attr:upsert({
    key = 'ATTR_STANIMA',
    nick = 'stanima',
    range = 1,
    save = {0},
})

player_attr:upsert({
    key = 'ATTR_EXP',
    nick = 'exp',
    range = 1,
    save = {0},
})

player_attr:upsert({
    key = 'ATTR_LEVEL',
    nick = 'level',
    range = 1,
    save = {0},
})

player_attr:upsert({
    key = 'ATTR_COIN',
    nick = 'coin',
    range = 1,
    save = {0},
})

player_attr:upsert({
    key = 'ATTR_COUPONS',
    nick = 'coupons',
    range = 1,
    save = {0},
})

player_attr:upsert({
    key = 'ATTR_LUCKY',
    nick = 'lucky',
    range = 1,
    save = {0},
})

player_attr:upsert({
    key = 'ATTR_ATTACK',
    nick = 'attack',
    range = 1,
    save = {0},
})

player_attr:upsert({
    key = 'ATTR_DEFENCE',
    nick = 'defence',
    range = 1,
    save = {0},
})

player_attr:upsert({
    key = 'ATTR_CRITICAL_RATE',
    nick = 'critical_rate',
    range = 1,
    save = {0},
})

player_attr:upsert({
    key = 'ATTR_CRITICAL_HURT',
    nick = 'critical_hurt',
    range = 1,
    save = {0},
})

player_attr:upsert({
    key = 'ATTR_HEAD',
    nick = 'head',
    range = 16,
    save = {0},
})

player_attr:upsert({
    key = 'ATTR_FACE',
    nick = 'face',
    range = 16,
    save = {0},
})

player_attr:upsert({
    key = 'ATTR_CLOTH',
    nick = 'cloth',
    range = 16,
    save = {0},
})

player_attr:upsert({
    key = 'ATTR_TROUSERS',
    nick = 'trousers',
    range = 16,
    save = {0},
})

player_attr:upsert({
    key = 'ATTR_SHOES',
    nick = 'shoes',
    range = 16,
    save = {0},
})

player_attr:upsert({
    key = 'ATTR_WEAPON',
    nick = 'weapon',
    range = 16,
    save = {0},
})

player_attr:upsert({
    key = 'ATTR_NECK',
    nick = 'neck',
    range = 0,
    save = {0},
})

player_attr:upsert({
    key = 'ATTR_RING',
    nick = 'ring',
    range = 0,
    save = {0},
})

player_attr:upsert({
    key = 'ATTR_SHUT_KEY1',
    nick = 'shut_key1',
    range = 1,
    save = {0},
})

player_attr:upsert({
    key = 'ATTR_SHUT_KEY2',
    nick = 'shut_key2',
    range = 1,
    save = {0},
})

player_attr:upsert({
    key = 'ATTR_SHUT_KEY3',
    nick = 'shut_key3',
    range = 1,
    save = {0},
})

player_attr:upsert({
    key = 'ATTR_SHUT_KEY4',
    nick = 'shut_key4',
    range = 1,
    save = {0},
})

player_attr:upsert({
    key = 'ATTR_SHUT_KEY5',
    nick = 'shut_key5',
    range = 1,
    save = {0},
})

player_attr:upsert({
    key = 'ATTR_SHUT_KEY6',
    nick = 'shut_key6',
    range = 1,
    save = {0},
})

player_attr:upsert({
    key = 'ATTR_SHUT_KEY7',
    nick = 'shut_key7',
    range = 1,
    save = {0},
})

player_attr:upsert({
    key = 'ATTR_SHUT_KEY8',
    nick = 'shut_key8',
    range = 1,
    save = {0},
})

player_attr:upsert({
    key = 'ATTR_MAP_ID',
    nick = 'map_id',
    range = 0,
    save = {0},
})

player_attr:upsert({
    key = 'ATTR_POS_X',
    nick = 'pos_x',
    range = 0,
    save = {0},
})

player_attr:upsert({
    key = 'ATTR_POS_Y',
    nick = 'pos_y',
    range = 0,
    save = {0},
})

player_attr:upsert({
    key = 'ATTR_POS_Z',
    nick = 'pos_z',
    range = 0,
    save = {0},
})

--general md5 version
player_attr:set_version('ef988fee02a7e7424eed976bca041cf9')