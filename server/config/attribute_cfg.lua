--attribute_cfg.lua
--source: attribute.csv
--luacheck: ignore 631

--获取配置表
local config_mgr = quanta.get("config_mgr")
local attribute = config_mgr:get_table("attribute")

--导出配置内容
attribute:upsert({
    complex=false,
    enum_key='ATTR_HP',
    id=1,
    increase=true,
    limit='ATTR_HP_MAX',
    nick='hp',
    type='int'
})

attribute:upsert({
    complex=false,
    enum_key='ATTR_MP',
    id=2,
    increase=true,
    limit='ATTR_MP_MAX',
    nick='mp',
    type='int'
})

attribute:upsert({
    complex=false,
    enum_key='ATTR_STAMINA',
    id=3,
    increase=true,
    limit='ATTR_STAMINA_MAX',
    nick='stamina',
    type='int'
})

attribute:upsert({
    complex=false,
    enum_key='ATTR_EXP',
    id=4,
    increase=true,
    limit='ATTR_EXP_MAX',
    nick='exp',
    type='int'
})

attribute:upsert({
    complex=true,
    enum_key='ATTR_HP_MAX',
    id=5,
    increase=true,
    nick='hp_max',
    type='int'
})

attribute:upsert({
    complex=true,
    enum_key='ATTR_MP_MAX',
    id=6,
    increase=true,
    nick='mp_max',
    type='int'
})

attribute:upsert({
    complex=true,
    enum_key='ATTR_STAMINA_MAX',
    id=7,
    increase=true,
    nick='stamina_max',
    type='int'
})

attribute:upsert({
    complex=false,
    enum_key='ATTR_EXP_MAX',
    id=8,
    increase=true,
    nick='exp_max',
    type='int'
})

attribute:upsert({
    complex=false,
    enum_key='ATTR_LEVEL',
    id=9,
    increase=false,
    nick='level',
    type='int'
})

attribute:upsert({
    complex=false,
    enum_key='ATTR_COIN',
    id=10,
    increase=true,
    nick='coin',
    type='int'
})

attribute:upsert({
    complex=false,
    enum_key='ATTR_NAME',
    id=11,
    increase=false,
    nick='name',
    type='string'
})

attribute:upsert({
    complex=false,
    enum_key='ATTR_DIAMOND',
    id=12,
    increase=true,
    nick='diamond',
    type='int'
})

attribute:upsert({
    complex=false,
    enum_key='ATTR_PROTO_ID',
    id=13,
    increase=false,
    nick='proto_id',
    type='int'
})

attribute:upsert({
    complex=false,
    enum_key='ATTR_LUCKY',
    id=14,
    increase=true,
    nick='lucky',
    type='int'
})

attribute:upsert({
    complex=false,
    enum_key='ATTR_GENDER',
    id=15,
    increase=false,
    nick='gender',
    type='int'
})

attribute:upsert({
    complex=false,
    enum_key='ATTR_CUSTOM',
    id=16,
    increase=false,
    nick='custom',
    type='bytes'
})

attribute:upsert({
    complex=false,
    enum_key='ATTR_VERSION',
    id=17,
    increase=false,
    nick='version',
    type='int'
})

attribute:upsert({
    complex=false,
    enum_key='ATTR_ONLINE_TIME',
    id=18,
    increase=true,
    nick='online_time',
    type='int'
})

attribute:upsert({
    complex=true,
    enum_key='ATTR_ATTACK',
    id=21,
    increase=true,
    nick='attack',
    type='int'
})

attribute:upsert({
    complex=true,
    enum_key='ATTR_DEFENCE',
    id=22,
    increase=true,
    nick='defence',
    type='int'
})

attribute:upsert({
    complex=false,
    enum_key='ATTR_CRITICAL_RATE',
    id=23,
    increase=true,
    nick='critical_rate',
    type='float'
})

attribute:upsert({
    complex=false,
    enum_key='ATTR_CRITICAL_HURT',
    id=24,
    increase=true,
    nick='critical_hurt',
    type='float'
})

attribute:upsert({
    complex=false,
    enum_key='ATTR_LOGIN_TIME',
    id=33,
    increase=false,
    nick='login_time',
    type='int'
})

attribute:upsert({
    complex=false,
    enum_key='ATTR_HEAD',
    id=51,
    increase=false,
    nick='head',
    type='int'
})

attribute:upsert({
    complex=false,
    enum_key='ATTR_FACE',
    id=52,
    increase=false,
    nick='face',
    type='int'
})

attribute:upsert({
    complex=false,
    enum_key='ATTR_CLOTH',
    id=53,
    increase=false,
    nick='cloth',
    type='int'
})

attribute:upsert({
    complex=false,
    enum_key='ATTR_TROUSERS',
    id=54,
    increase=false,
    nick='trousers',
    type='int'
})

attribute:upsert({
    complex=false,
    enum_key='ATTR_SHOES',
    id=55,
    increase=false,
    nick='shoes',
    type='int'
})

attribute:upsert({
    complex=false,
    enum_key='ATTR_WEAPON',
    id=56,
    increase=false,
    nick='weapon',
    type='int'
})

attribute:upsert({
    complex=false,
    enum_key='ATTR_NECK',
    id=57,
    increase=false,
    nick='neck',
    type='int'
})

attribute:upsert({
    complex=false,
    enum_key='ATTR_RING',
    id=58,
    increase=false,
    nick='ring',
    type='int'
})

attribute:upsert({
    complex=false,
    enum_key='ATTR_MAP_ID',
    id=101,
    increase=false,
    nick='map_id',
    type='int'
})

attribute:upsert({
    complex=false,
    enum_key='ATTR_POS_X',
    id=102,
    increase=false,
    nick='pos_x',
    type='int'
})

attribute:upsert({
    complex=false,
    enum_key='ATTR_POS_Y',
    id=103,
    increase=false,
    nick='pos_y',
    type='int'
})

attribute:upsert({
    complex=false,
    enum_key='ATTR_POS_Z',
    id=104,
    increase=false,
    nick='pos_z',
    type='int'
})

attribute:upsert({
    complex=false,
    enum_key='ATTR_LINE',
    id=105,
    increase=false,
    nick='line',
    type='int'
})

attribute:update()
