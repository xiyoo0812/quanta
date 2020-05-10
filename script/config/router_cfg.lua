--router_cfg.lua
--luacheck: ignore 631

--获取配置表
local config_mgr = quanta.config_mgr
local router = config_mgr:get_table("router")

--导出版本号
router:set_version(10000)

--导出配置内容
router:upsert({
    quanta_deploy = 'publish',
    group = 1,
    index = 1,
    addr = '10.72.17.44:9601',
})

router:upsert({
    quanta_deploy = 'publish',
    group = 1,
    index = 2,
    addr = '10.72.17.44:9602',
})

router:upsert({
    quanta_deploy = 'devlop',
    group = 1,
    index = 1,
    addr = '192.168.131.208:9601',
})

router:upsert({
    quanta_deploy = 'devlop',
    group = 1,
    index = 2,
    addr = '192.168.131.208:9602',
})

router:upsert({
    quanta_deploy = 'local',
    group = 1,
    index = 1,
    addr = '127.0.0.1:9601',
})
