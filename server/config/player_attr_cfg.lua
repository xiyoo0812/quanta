--player_attr_cfg.lua
--luacheck: ignore 631

--获取配置表
local config_mgr = quanta.get("config_mgr")
local player_attr = config_mgr:get_table("player_attr")

--导出配置内容
player_attr:upsert({
    back=false,
    key='ATTR_HP',
    limit='ATTR_HP_MAX',
    range=16,
    save=true
})

player_attr:upsert({
    back=false,
    key='ATTR_MP',
    limit='ATTR_MP_MAX',
    range=1,
    save=true
})

player_attr:upsert({
    back=false,
    key='ATTR_STAMINA',
    limit='ATTR_STAMINA_MAX',
    range=1,
    save=true
})

player_attr:upsert({
    back=false,
    key='ATTR_EXP',
    limit='ATTR_EXP_MAX',
    range=1,
    save=true
})

player_attr:upsert({
    back=false,
    key='ATTR_HP_MAX',
    range=16,
    save=false
})

player_attr:upsert({
    back=false,
    key='ATTR_MP_MAX',
    range=1,
    save=false
})

player_attr:upsert({
    back=false,
    key='ATTR_STAMINA_MAX',
    range=1,
    save=false
})

player_attr:upsert({
    back=false,
    key='ATTR_EXP_MAX',
    range=1,
    save=false
})

player_attr:upsert({
    back=false,
    key='ATTR_LEVEL',
    range=16,
    save=true
})

player_attr:upsert({
    back=false,
    key='ATTR_COIN',
    range=1,
    save=true
})

player_attr:upsert({
    back=false,
    key='ATTR_NAME',
    range=16,
    save=true
})

player_attr:upsert({
    back=false,
    key='ATTR_DIAMOND',
    range=1,
    save=true
})

player_attr:upsert({
    back=false,
    key='ATTR_LUCKY',
    range=1,
    save=true
})

player_attr:upsert({
    back=false,
    key='ATTR_GENDER',
    range=1,
    save=false
})

player_attr:upsert({
    back=false,
    key='ATTR_CUSTOM',
    range=16,
    save=false
})

player_attr:upsert({
    back=false,
    key='ATTR_VERSION',
    range=0,
    save=true
})

player_attr:upsert({
    back=false,
    key='ATTR_ONLINE_TIME',
    range=1,
    save=true
})

player_attr:upsert({
    back=false,
    key='ATTR_ATTACK',
    range=1,
    save=false
})

player_attr:upsert({
    back=false,
    key='ATTR_DEFENCE',
    range=1,
    save=false
})

player_attr:upsert({
    back=false,
    key='ATTR_CRITICAL_RATE',
    range=1,
    save=false
})

player_attr:upsert({
    back=false,
    key='ATTR_CRITICAL_HURT',
    range=1,
    save=false
})

player_attr:upsert({
    back=false,
    key='ATTR_HEAD',
    range=16,
    save=true
})

player_attr:upsert({
    back=false,
    key='ATTR_FACE',
    range=16,
    save=true
})

player_attr:upsert({
    back=false,
    key='ATTR_CLOTH',
    range=16,
    save=true
})

player_attr:upsert({
    back=false,
    key='ATTR_TROUSERS',
    range=16,
    save=true
})

player_attr:upsert({
    back=false,
    key='ATTR_SHOES',
    range=16,
    save=true
})

player_attr:upsert({
    back=false,
    key='ATTR_WEAPON',
    range=16,
    save=true
})

player_attr:upsert({
    back=false,
    key='ATTR_NECK',
    range=0,
    save=false
})

player_attr:upsert({
    back=false,
    key='ATTR_RING',
    range=0,
    save=false
})

player_attr:upsert({
    back=false,
    key='ATTR_MAP_ID',
    range=0,
    save=true
})

player_attr:upsert({
    back=false,
    key='ATTR_POS_X',
    range=0,
    save=true
})

player_attr:upsert({
    back=false,
    key='ATTR_POS_Y',
    range=0,
    save=true
})

player_attr:upsert({
    back=false,
    key='ATTR_POS_Z',
    range=0,
    save=true
})

player_attr:upsert({
    back=false,
    key='ATTR_LINE',
    range=0,
    save=true
})

player_attr:upsert({
    back=false,
    key='ATTR_LOGIN_TIME',
    range=0,
    save=true
})

player_attr:update()
