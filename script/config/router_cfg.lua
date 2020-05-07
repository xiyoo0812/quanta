--router_cfg.lua
--luacheck: ignore 631

--获取配置表
local config_mgr = quanta.config_mgr
local router = config_mgr:get_table("router")

--导出版本号
router:set_version(10000)

--导出配置内容
router:upsert({
    id = 1,
    group = 1,
    index = 1,
    group_name = 'klbq_plat_router_pub',
    addr = '10.72.17.44:9601',
})

router:upsert({
    id = 2,
    group = 1,
    index = 2,
    group_name = 'klbq_plat_router_pub',
    addr = '10.72.17.44:9602',
})

router:upsert({
    id = 1001,
    group = 2,
    index = 1,
    group_name = 'klbq_plat_router_dev',
    addr = '192.168.131.208:9601',
})

router:upsert({
    id = 1002,
    group = 2,
    index = 2,
    group_name = 'klbq_plat_router_dev',
    addr = '192.168.131.208:9602',
})

router:upsert({
    id = 2001,
    group = 3,
    index = 1,
    group_name = 'klbq_plat_router_loc',
    addr = '127.0.0.1:9601',
})
