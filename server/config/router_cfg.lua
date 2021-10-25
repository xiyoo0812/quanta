--router_cfg.lua
--luacheck: ignore 631

--获取配置表
local config_mgr = quanta.get("config_mgr")
local router = config_mgr:get_table("router")

--导出版本号
router:set_version(10000)

--导出配置内容
router:upsert({
    quanta_deploy = 'publish',
    host_id = 1,
    host = '9.134.163.87',
    count = 2,
    port = 9001,
})

router:upsert({
    quanta_deploy = 'develop',
    host_id = 1,
    host = '9.134.163.87',
    count = 2,
    port = 9001,
})

router:upsert({
    quanta_deploy = 'local',
    host_id = 1,
    host = '127.0.0.1',
    count = 2,
    port = 9001,
})
