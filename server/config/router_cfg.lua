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
    group = 1,
    index = 1,
    addr = '9.134.163.87:9001',
})

router:upsert({
    quanta_deploy = 'publish',
    group = 1,
    index = 2,
    addr = '9.134.163.87:9002',
})

router:upsert({
    quanta_deploy = 'develop',
    group = 1,
    index = 1,
    addr = '9.134.163.87:9001',
})

router:upsert({
    quanta_deploy = 'local',
    group = 1,
    index = 1,
    addr = '127.0.0.1:9001',
})
