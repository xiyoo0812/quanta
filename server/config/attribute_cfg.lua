--attribute_cfg.lua
--luacheck: ignore 631

--获取配置表
local config_mgr = quanta.get("config_mgr")
local attribute = config_mgr:get_table("attribute")

--导出配置内容
attribute:upsert({
    id = 1,
    enum_key = 'ATTR_HP',
    nick = 'hp',
})

attribute:upsert({
    id = 2,
    enum_key = 'ATTR_MP',
    nick = 'mp',
})

attribute:upsert({
    id = 3,
    enum_key = 'ATTR_POWER',
    nick = 'power',
})

attribute:upsert({
    id = 4,
    enum_key = 'ATTR_STANIMA',
    nick = 'stanima',
})

attribute:upsert({
    id = 5,
    enum_key = 'ATTR_EXP',
    nick = 'exp',
})

attribute:upsert({
    id = 6,
    enum_key = 'ATTR_LEVEL',
    nick = 'level',
})

attribute:upsert({
    id = 7,
    enum_key = 'ATTR_COIN',
    nick = 'coin',
})

attribute:upsert({
    id = 8,
    enum_key = 'ATTR_COUPONS',
    nick = 'coupons',
})

attribute:upsert({
    id = 9,
    enum_key = 'ATTR_LUCKY',
    nick = 'lucky',
})

attribute:upsert({
    id = 21,
    enum_key = 'ATTR_ATTACK',
    nick = 'attack',
})

attribute:upsert({
    id = 22,
    enum_key = 'ATTR_DEFENCE',
    nick = 'defence',
})

attribute:upsert({
    id = 23,
    enum_key = 'ATTR_CRITICAL_RATE',
    nick = 'critical_rate',
})

attribute:upsert({
    id = 24,
    enum_key = 'ATTR_CRITICAL_HURT',
    nick = 'critical_hurt',
})

attribute:upsert({
    id = 51,
    enum_key = 'ATTR_HEAD',
    nick = 'head',
})

attribute:upsert({
    id = 52,
    enum_key = 'ATTR_FACE',
    nick = 'face',
})

attribute:upsert({
    id = 55,
    enum_key = 'ATTR_CLOTH',
    nick = 'cloth',
})

attribute:upsert({
    id = 56,
    enum_key = 'ATTR_TROUSERS',
    nick = 'trousers',
})

attribute:upsert({
    id = 57,
    enum_key = 'ATTR_SHOES',
    nick = 'shoes',
})

attribute:upsert({
    id = 58,
    enum_key = 'ATTR_WEAPON',
    nick = 'weapon',
})

attribute:upsert({
    id = 53,
    enum_key = 'ATTR_NECK',
    nick = 'neck',
})

attribute:upsert({
    id = 54,
    enum_key = 'ATTR_RING',
    nick = 'ring',
})

attribute:upsert({
    id = 61,
    enum_key = 'ATTR_SHUT_KEY1',
    nick = 'shut_key1',
})

attribute:upsert({
    id = 62,
    enum_key = 'ATTR_SHUT_KEY2',
    nick = 'shut_key2',
})

attribute:upsert({
    id = 63,
    enum_key = 'ATTR_SHUT_KEY3',
    nick = 'shut_key3',
})

attribute:upsert({
    id = 64,
    enum_key = 'ATTR_SHUT_KEY4',
    nick = 'shut_key4',
})

attribute:upsert({
    id = 65,
    enum_key = 'ATTR_SHUT_KEY5',
    nick = 'shut_key5',
})

attribute:upsert({
    id = 66,
    enum_key = 'ATTR_SHUT_KEY6',
    nick = 'shut_key6',
})

attribute:upsert({
    id = 67,
    enum_key = 'ATTR_SHUT_KEY7',
    nick = 'shut_key7',
})

attribute:upsert({
    id = 68,
    enum_key = 'ATTR_SHUT_KEY8',
    nick = 'shut_key8',
})

attribute:upsert({
    id = 101,
    enum_key = 'ATTR_MAP_ID',
    nick = 'map_id',
})

attribute:upsert({
    id = 102,
    enum_key = 'ATTR_POS_X',
    nick = 'pos_x',
})

attribute:upsert({
    id = 103,
    enum_key = 'ATTR_POS_Y',
    nick = 'pos_y',
})

attribute:upsert({
    id = 104,
    enum_key = 'ATTR_POS_Z',
    nick = 'pos_z',
})

--general md5 version
attribute:set_version('1bedf9b93dc38473a726d5be7599e371')