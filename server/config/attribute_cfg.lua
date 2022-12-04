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
    increase = true,
})

attribute:upsert({
    id = 2,
    enum_key = 'ATTR_MP',
    nick = 'mp',
    increase = true,
})

attribute:upsert({
    id = 3,
    enum_key = 'ATTR_STANIMA',
    nick = 'stanima',
    increase = true,
})

attribute:upsert({
    id = 4,
    enum_key = 'ATTR_EXP',
    nick = 'exp',
    increase = true,
})

attribute:upsert({
    id = 5,
    enum_key = 'ATTR_HP_MAX',
    nick = 'hp_max',
    increase = true,
})

attribute:upsert({
    id = 6,
    enum_key = 'ATTR_MP_MAX',
    nick = 'mp_max',
    increase = true,
})

attribute:upsert({
    id = 7,
    enum_key = 'ATTR_STANIMA_MAX',
    nick = 'stanima_max',
    increase = true,
})

attribute:upsert({
    id = 8,
    enum_key = 'ATTR_EXP_MAX',
    nick = 'exp_max',
    increase = true,
})

attribute:upsert({
    id = 9,
    enum_key = 'ATTR_LEVEL',
    nick = 'level',
    increase = false,
})

attribute:upsert({
    id = 10,
    enum_key = 'ATTR_COIN',
    nick = 'coin',
    increase = true,
})

attribute:upsert({
    id = 11,
    enum_key = 'ATTR_JEWEL',
    nick = 'jewel',
    increase = true,
})

attribute:upsert({
    id = 12,
    enum_key = 'ATTR_DIAMOND',
    nick = 'diamond',
    increase = true,
})

attribute:upsert({
    id = 13,
    enum_key = 'ATTR_PROTO_ID',
    nick = 'proto_id',
    increase = false,
})

attribute:upsert({
    id = 14,
    enum_key = 'ATTR_LUCKY',
    nick = 'lucky',
    increase = true,
})

attribute:upsert({
    id = 21,
    enum_key = 'ATTR_ATTACK',
    nick = 'attack',
    increase = true,
})

attribute:upsert({
    id = 22,
    enum_key = 'ATTR_DEFENCE',
    nick = 'defence',
    increase = true,
})

attribute:upsert({
    id = 23,
    enum_key = 'ATTR_CRITICAL_RATE',
    nick = 'critical_rate',
    increase = true,
})

attribute:upsert({
    id = 24,
    enum_key = 'ATTR_CRITICAL_HURT',
    nick = 'critical_hurt',
    increase = true,
})

attribute:upsert({
    id = 51,
    enum_key = 'ATTR_HEAD',
    nick = 'head',
    increase = false,
})

attribute:upsert({
    id = 52,
    enum_key = 'ATTR_FACE',
    nick = 'face',
    increase = false,
})

attribute:upsert({
    id = 53,
    enum_key = 'ATTR_CLOTH',
    nick = 'cloth',
    increase = false,
})

attribute:upsert({
    id = 54,
    enum_key = 'ATTR_TROUSERS',
    nick = 'trousers',
    increase = false,
})

attribute:upsert({
    id = 55,
    enum_key = 'ATTR_SHOES',
    nick = 'shoes',
    increase = false,
})

attribute:upsert({
    id = 56,
    enum_key = 'ATTR_WEAPON',
    nick = 'weapon',
    increase = false,
})

attribute:upsert({
    id = 57,
    enum_key = 'ATTR_NECK',
    nick = 'neck',
    increase = false,
})

attribute:upsert({
    id = 58,
    enum_key = 'ATTR_RING',
    nick = 'ring',
    increase = false,
})

attribute:upsert({
    id = 101,
    enum_key = 'ATTR_MAP_ID',
    nick = 'map_id',
    increase = false,
})

attribute:upsert({
    id = 102,
    enum_key = 'ATTR_POS_X',
    nick = 'pos_x',
    increase = false,
})

attribute:upsert({
    id = 103,
    enum_key = 'ATTR_POS_Y',
    nick = 'pos_y',
    increase = false,
})

attribute:upsert({
    id = 104,
    enum_key = 'ATTR_POS_Z',
    nick = 'pos_z',
    increase = false,
})

attribute:upsert({
    id = 105,
    enum_key = 'ATTR_LINE',
    nick = 'line',
    increase = false,
})

attribute:update()
