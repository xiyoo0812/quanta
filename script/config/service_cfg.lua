--service_cfg.lua
--luacheck: ignore 631

--获取配置表
local config_mgr = quanta.config_mgr
local service = config_mgr:get_table("service")

--导出版本号
service:set_version(10000)

--导出配置内容
service:upsert({
    quanta_deploy = 1,
    quanta_deploy_name = 'klbq_plat_pub',
    id = 1,
    name = 'router',
    router_group = {},
})

service:upsert({
    quanta_deploy = 1,
    quanta_deploy_name = 'klbq_plat_pub',
    id = 2,
    name = 'monitor',
    router_group = {},
})

service:upsert({
    quanta_deploy = 1,
    quanta_deploy_name = 'klbq_plat_pub',
    id = 3,
    name = 'gateway',
    router_group = {1},
})

service:upsert({
    quanta_deploy = 1,
    quanta_deploy_name = 'klbq_plat_pub',
    id = 4,
    name = 'platform',
    router_group = {1},
})

service:upsert({
    quanta_deploy = 1,
    quanta_deploy_name = 'klbq_plat_pub',
    id = 5,
    name = 'dbsvr',
    router_group = {1},
})

service:upsert({
    quanta_deploy = 1,
    quanta_deploy_name = 'klbq_plat_pub',
    id = 6,
    name = 'proxy',
    router_group = {1},
})

service:upsert({
    quanta_deploy = 1,
    quanta_deploy_name = 'klbq_plat_pub',
    id = 7,
    name = 'test',
    router_group = {1},
})

service:upsert({
    quanta_deploy = 1,
    quanta_deploy_name = 'klbq_plat_pub',
    id = 8,
    name = 'robot',
    router_group = {},
})

service:upsert({
    quanta_deploy = 2,
    quanta_deploy_name = 'klbq_plat_dev',
    id = 1,
    name = 'router',
    router_group = {},
})

service:upsert({
    quanta_deploy = 2,
    quanta_deploy_name = 'klbq_plat_dev',
    id = 2,
    name = 'monitor',
    router_group = {},
})

service:upsert({
    quanta_deploy = 2,
    quanta_deploy_name = 'klbq_plat_dev',
    id = 3,
    name = 'gateway',
    router_group = {1},
})

service:upsert({
    quanta_deploy = 2,
    quanta_deploy_name = 'klbq_plat_dev',
    id = 4,
    name = 'platform',
    router_group = {1},
})

service:upsert({
    quanta_deploy = 2,
    quanta_deploy_name = 'klbq_plat_dev',
    id = 5,
    name = 'dbsvr',
    router_group = {1},
})

service:upsert({
    quanta_deploy = 2,
    quanta_deploy_name = 'klbq_plat_dev',
    id = 6,
    name = 'proxy',
    router_group = {1},
})

service:upsert({
    quanta_deploy = 2,
    quanta_deploy_name = 'klbq_plat_dev',
    id = 7,
    name = 'test',
    router_group = {1},
})

service:upsert({
    quanta_deploy = 2,
    quanta_deploy_name = 'klbq_plat_dev',
    id = 8,
    name = 'robot',
    router_group = {},
})

service:upsert({
    quanta_deploy = 3,
    quanta_deploy_name = 'klbq_plat_loc',
    id = 1,
    name = 'router',
    router_group = {},
})

service:upsert({
    quanta_deploy = 3,
    quanta_deploy_name = 'klbq_plat_loc',
    id = 2,
    name = 'monitor',
    router_group = {},
})

service:upsert({
    quanta_deploy = 3,
    quanta_deploy_name = 'klbq_plat_loc',
    id = 3,
    name = 'gateway',
    router_group = {1},
})

service:upsert({
    quanta_deploy = 3,
    quanta_deploy_name = 'klbq_plat_loc',
    id = 4,
    name = 'platform',
    router_group = {1},
})

service:upsert({
    quanta_deploy = 3,
    quanta_deploy_name = 'klbq_plat_loc',
    id = 5,
    name = 'dbsvr',
    router_group = {1},
})

service:upsert({
    quanta_deploy = 3,
    quanta_deploy_name = 'klbq_plat_loc',
    id = 6,
    name = 'proxy',
    router_group = {1},
})

service:upsert({
    quanta_deploy = 3,
    quanta_deploy_name = 'klbq_plat_loc',
    id = 7,
    name = 'test',
    router_group = {1},
})

service:upsert({
    quanta_deploy = 3,
    quanta_deploy_name = 'klbq_plat_loc',
    id = 8,
    name = 'robot',
    router_group = {},
})
