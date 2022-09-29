--router_cfg.lua
--luacheck: ignore 631

--获取配置表
local config_mgr = quanta.get("config_mgr")
local router = config_mgr:get_table("router")

--导出配置内容
router:upsert({
    cluster = 'publish',
    host = '127.0.0.1',
    count = 2,
    port = 9001,
})

router:upsert({
    cluster = 'develop',
    host = '127.0.0.1',
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
router:set_version('e4636bff24d874fa827f4f9670f4ece8')