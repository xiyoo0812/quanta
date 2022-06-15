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
    host = '10.98.8.155',
    count = 2,
    port = 9001,
})

--general md5 version
router:set_version('3f5cafe47a12cc3b32accf54889755bf')