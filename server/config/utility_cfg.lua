--utility_cfg.lua
--luacheck: ignore 631

--获取配置表
local config_mgr = quanta.get("config_mgr")
local utility = config_mgr:get_table("utility")

--导出配置内容
utility:upsert({
    ID = 1,
    key = 'flush_day_hour',
    value = '5',
})

utility:upsert({
    ID = 2,
    key = 'flush_week_day',
    value = '1',
})

utility:upsert({
    ID = 3,
    key = 'born_map_id',
    value = '1',
})

utility:upsert({
    ID = 4,
    key = 'born_pox_x',
    value = '0',
})

utility:upsert({
    ID = 5,
    key = 'born_pox_y',
    value = '1200',
})

utility:upsert({
    ID = 6,
    key = 'born_pox_z',
    value = '0',
})

--general md5 version
utility:set_version('01e3660460b4545fe18137445ab133ba')