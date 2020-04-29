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
    group_name = 'main_group',
    addr = '127.0.0.1:9001',
})

router:upsert({
    id = 2,
    group = 1,
    index = 2,
    group_name = 'main_group',
    addr = '127.0.0.1:9002',
})

router:upsert({
    id = 3,
    group = 2,
    index = 3,
    group_name = 'ds_group',
    addr = '127.0.0.1:9003',
})

router:upsert({
    id = 4,
    group = 2,
    index = 4,
    group_name = 'ds_group',
    addr = '127.0.0.1:9004',
})

router:upsert({
    id = 5,
    group = 3,
    index = 5,
    group_name = 'data_group',
    addr = '127.0.0.1:9005',
})

router:upsert({
    id = 6,
    group = 3,
    index = 6,
    group_name = 'data_group',
    addr = '127.0.0.1:9006',
})

router:upsert({
    id = 7,
    group = 4,
    index = 7,
    group_name = 'plat_group',
    addr = '127.0.0.1:9007',
})

router:upsert({
    id = 8,
    group = 4,
    index = 8,
    group_name = 'plat_group',
    addr = '127.0.0.1:9008',
})
