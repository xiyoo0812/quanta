--router_cfg.lua
--luacheck: ignore 631

--获取配置表
local config_mgr = quanta.get("config_mgr")
local router = config_mgr:get_table("router")

--导出配置内容
router:upsert({
    cluster = 'publish',
    host = '9.134.163.87',
    count = 2,
    port = 9001,
})

router:upsert({
    cluster = 'develop',
    host = '9.134.163.87',
    count = 2,
    port = 9001,
})

router:upsert({
    cluster = 'local',
    host = '127.0.0.1',
    count = 2,
    port = 9001,
})

--general md5 version
router:set_version('f51c280fa8013a075c35ec8bb793385f')